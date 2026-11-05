-- wowF Legacy (8-oct): perks Legacy que afectan a las profesiones, Legacy Points por profesion y certificaciones (titulo de cuenta).
--   * Seccion corta al final de Profesiones del Libro (WowF.seccionLegacy), paso de la ayuda (WowF.pasoAyudaLegacy) y
--     recordatorio de Skinning (WowF.notaSkinningUnaVez, lo usa wowF_AreaMobs.lua).
--   * Perks detectados con pcall(IsPlayerSpell, id): solo se afirma "lo tienes" si el cliente dice true; si no, nota general.
-- Fuentes: Blizzard (articulo oficial del sistema Legacy, 23-sep-2026), hechizos del cliente beta 1.60.1.70245 y Wowhead /forever; cambios de la build 70425 (foreverchanges.pro/patch-notes, 15-oct-2026)
-- (spell=1225451, objetos Certification). Rangos y numeros = beta: pueden cambiar; se dice "se actualizara".

WowF = WowF or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end

WowF.LEGACY_URL = "https://worldofwarcraft.blizzard.com/en-us/news/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system"
WowF.SKILLUP_URL = "https://www.curseforge.com/wow/addons/skillup-forever"

-- Profesiones de fabricar que dan Legacy Points (150, 225 y 300) y certificacion (titulo de cuenta)
local FABRICAR = {
  { id = 171, titulo = "the Alchemist" }, { id = 164, titulo = "the Blacksmith" }, { id = 333, titulo = "the Enchanter" },
  { id = 202, titulo = "the Engineer" }, { id = 165, titulo = "the Leatherworker" }, { id = 197, titulo = "the Tailor" },
}
local NOMBRE = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [165] = "Leatherworking", [197] = "Tailoring" }

-- Perks del arbol Legacy ACTUAL del cliente beta (12-oct: TraitTree 1187 profesiones, 1188 aventura, 1189 combate; sistema 45).
-- id = hechizo, nodo = TraitNode, r = rangos, v = valor por rango (curvas del cliente), a = arbol, para = profesiones (nil = todos),
-- usa = que parte del addon lo tiene en cuenta (nil = el addon no calcula nada con el: solo se informa).
local PERKS = {
  -- Build 70425: Master Chef y Luremaster pasan una columna a la izquierda en el arbol (siguen pidiendo 5 puntos); aqui no se guarda la columna.
  { id = 1225457, nodo = 110289, a = 1, n = "Master Chef", r = 5, v = { 10, 20, 30, 40, 50 }, para = { 185 },
    es = "%d %% de probabilidad de una comida extra al cocinar.", en = "%d%% chance of an extra result when cooking.", },
  { id = 1225451, nodo = 110290, a = 1, n = "Working Overtime", r = 5, v = { 4, 8, 12, 16, 20 },
    es = "+%d %% de probabilidad de subir habilidad en todas las profesiones.", en = "+%d%% chance to gain skill in all professions.",
    usa = { "Profesiones: cuántas veces fabricar y materiales de cada paso (estimado)", "Professions: how many crafts and materials per step (estimate)" } },
  { id = 1225459, nodo = 110286, a = 1, n = "Bartering", r = 2, v = { 5, 10 },
    es = "-%d %% en el precio en oro de los vendedores (desde la build 70425 ya no rebaja el entrenamiento ni las reparaciones).", en = "-%d%% on the gold price of vendors (since build 70425 it no longer discounts training or repairs)." },
  { id = 1225469, nodo = 110284, a = 1, n = "Dedicated Study", r = 1, v = { 1 },
    es = "una vez al día: +%d a tu profesión más baja.", en = "once a day: +%d to your lowest profession.", },
  { id = 1225435, nodo = 110291, a = 1, n = "Bountiful Harvest", r = 5, v = { 20, 40, 60, 80, 100 }, para = { 186, 182, 393 },
    es = "+%d %% de materiales escasos (Scarce) al recolectar.", en = "+%d%% Scarce materials when gathering." },
  { id = 1225456, nodo = 110292, a = 1, n = "Performance Bonus", r = 3, v = { 5, 10, 15 },
    es = "%d %% de probabilidad de Merchant's Favor doble al entregar una caja.", en = "%d%% chance of double Merchant's Favor when turning in a crate.",
    usa = { "Merchant's Favor y cajas: Favor medio por caja", "Merchant's Favor and crates: average Favor per crate" } },
  { id = 1225455, nodo = 110293, a = 1, n = "Luremaster", r = 2, v = { 25, 50 }, para = { 356 },
    es = "%d %% de probabilidad de un pez extra con Lure.", en = "%d%% chance of an extra fish with a Lure." },
  { id = 1225477, nodo = 110305, a = 2, n = "High Alert", r = 2, v = { 1, 2 },
    es = "ves el sigilo como si tuvieras %d nivel(es) mas (no en campos de batalla).", en = "you detect stealth as if you were %d level(s) higher (not in battlegrounds).",
    usa = { "Consumibles: la nota de ver el sigilo", "Consumables: the stealth detection note" } },
  { id = 1225478, nodo = 110301, a = 2, n = "Well Rested", r = 5, v = { 4, 8, 12, 16, 20 },
    es = "el descanso (rested XP) se llena %d %% mas rapido y su tope sube.", en = "rested XP builds %d%% faster and its cap goes up." },
  { id = 1225474, nodo = 110298, a = 2, n = "Talented", r = 5, v = { 1, 2, 3, 4, 5 }, eleccion = true, entradas = { [136852] = 1, [137374] = 2, [137373] = 3, [137372] = 4, [137371] = 5 },
    es = "puntos de talento desde un nivel antes por rango (%d de adelanto; tope 51).", en = "talent points from one level earlier per rank (%d ahead; cap 51).",
    usa = { "Talentos: el nivel de cada punto de la guia (lee tus puntos reales)", "Talents: the level of each guide point (reads your real points)" } },
  { id = 1225472, nodo = 110296, a = 2, n = "Thrill of Adventure", r = 5, v = { 1, 2, 3, 4, 5 },
    es = "recuperas %d %% de vida y mana al matar (no en mazmorras).", en = "you restore %d%% health and mana on a kill (not in dungeons)." },
  { id = 1225479, nodo = 110304, a = 2, n = "Field Guide", r = 3, v = { 8, 17, 25 },
    es = "-%d %% de espera para poner objetos del campamento.", en = "-%d%% cooldown on adding camp features.",
    usa = { "Campamento: la espera de los objetos", "Camp: the camp item cooldown" } },
  { id = 1225490, nodo = 110300, a = 2, n = "Frequent Flier", r = 1, v = { 50 },
    es = "-%d %% en el precio de los vuelos y vuelas mas rapido.", en = "-%d%% flight cost and faster flights." },
  { id = 1225475, nodo = 110303, a = 2, n = "Field Medicine", r = 2, v = { 5, 10 },
    es = "Recently Bandaged dura %d s menos (no en mazmorras).", en = "Recently Bandaged lasts %d sec less (not in dungeons).",
    usa = { "Consumibles: vendas", "Consumables: bandages" } },
  { id = 1225501, nodo = 110319, a = 3, n = "For Great Honor", r = 5, v = { 1, 2, 3, 4, 5 },
    es = "mas Honor (rango %d).", en = "more Honor (rank %d)." },
  { id = 1225499, nodo = 110313, a = 3, n = "Gourmand", r = 3, v = { 33, 67, 100 },
    es = "el efecto de la comida dura %d %% mas.", en = "food buffs last %d%% longer.",
    usa = { "Consumibles: comida", "Consumables: food" } },
  { id = 1225502, nodo = 110316, a = 3, n = "Permanence", r = 2, v = { 1, 2 },
    es = "los buffs de grupo largos y el descanso del campamento duran mas (rango %d).", en = "long group buffs and camp rest last longer (rank %d)." },
  { id = 1225500, nodo = 110315, a = 3, n = "The Quick and the Dead", r = 2, v = { 1, 2 },
    es = "vas mas rapido muerto y tras resucitar tus hechizos de ayuda son gratis un rato (rango %d; desde la build 70425 alcanza mas hechizos de Priest).", en = "faster while dead and free helpful spells for a while after resurrecting (rank %d; since build 70425 it covers more Priest spells)." },
  { id = 1225503, nodo = 110309, a = 3, n = "Reagent Economy", r = 1, v = { 1 },
    es = "tus habilidades de clase no gastan reagents de vendedor.", en = "your class abilities don't use vendor reagents.",
    usa = { "Consumibles: reagents de clase", "Consumables: class reagents" } },
  { id = 1225497, nodo = 110318, a = 3, n = "Reinforce", r = 5, v = { 8, 16, 24, 32, 40 },
    es = "-%d %% de durabilidad perdida al morir.", en = "-%d%% durability loss when you die.",
    usa = { "Vendedor: aviso de durabilidad", "Vendor: durability warning" } },
  { id = 1225485, nodo = 110314, a = 3, n = "Diplomat", r = 5, v = { 2, 4, 6, 8, 10 },
    es = "+%d %% de reputacion.", en = "+%d%% reputation." },
}
local ARBOL = { { "Profesiones y comercio", "Professions and trade" }, { "Aventura", "Adventure" }, { "Combate, PvP y varios", "Combat, PvP and more" } }
WowF.LEGACY_SISTEMA = 45
local POR_ID = {}
for _, p in ipairs(PERKS) do POR_ID[p.id] = p end
WowF.LEGACY_PERKS = PERKS

local function tieneHechizo(id)
  local ok, si = pcall(function()
    if IsPlayerSpell then return IsPlayerSpell(id) == true end
    if IsSpellKnown then return IsSpellKnown(id) == true end
    return false
  end)
  return ok and si or false
end

-- Perks que el cliente confirma que tienes (lista de nombres; vacia = no se sabe o ninguno)
function WowF.legacyPerksActivos()
  local t = {}
  for _, p in ipairs(PERKS) do if WowF.legacyRango and WowF.legacyRango(p.id).rango > 0 then table.insert(t, p.n) end end
  return t
end

local function misProfes()
  local t = {}
  if WowF.profesiones then
    local ok, lista = pcall(WowF.profesiones)
    if ok and type(lista) == "table" then for _, p in ipairs(lista) do if p.id then t[p.id] = tonumber(p.rango) or 0 end end end
  end
  return t
end

local function sirve(p, mias)
  if not p.para then return true end
  for _, id in ipairs(p.para) do if mias[id] then return true end end
  return false
end

-- Seccion del Libro (pestana Profesiones)
function WowF.seccionLegacy(p, h)
  local mias = misProfes()
  h.cab(Y(ORO .. L("Legacy: tus ventajas de cuenta y lo que cambian en el addon", "Legacy: your account perks and what they change in the addon") .. "|r"))
  h.nota(Y(GRIS .. L("Legacy Points de tu cuenta (no Hardcore). Cada personaje gasta hasta 16. Se abre con la tecla Y o el escudo del menu.",
    "Your account's Legacy Points (not Hardcore). Each character spends up to 16. Open it with the Y key or the shield in the menu.") .. "|r"))
  -- 12-oct: los 3 arboles Legacy con tu rango real y que cambia en el addon; primero los que tienes, luego los que te sirven
  if WowF.legacyDiagnostico then WowF.legacyDiagnostico() end
  local hay = false
  for a = 1, 3 do
    local tengo, resto = {}, {}
    for _, x in ipairs(PERKS) do
      if x.a == a and sirve(x, mias) then
        local r = WowF.legacyRango(x.id)
        table.insert(r.rango > 0 and tengo or resto, { x = x, r = r })
      end
    end
    h.nota(Y(ORO .. L(ARBOL[a][1], ARBOL[a][2]) .. "|r"))
    for _, lista in ipairs({ tengo, resto }) do
      for _, e in ipairs(lista) do
        local x, r = e.x, e.r
        local tiene = r.rango > 0
        if tiene then hay = true end
        local rg = tiene and (VERDE .. r.rango .. "/" .. x.r .. (r.seguro and "" or L(" o mas", " or more")) .. "|r") or (GRIS .. "0/" .. x.r .. "|r")
        local val = x.v[math.max(1, r.rango)] or x.v[1]
        local desc = string.format(L(x.es, x.en), val) .. (tiene and "" or L(" (con 1 rango)", " (with 1 rank)"))
        local efecto = x.usa and ((tiene and VERDE or BLANCO) .. L("En el addon: ", "In the addon: ") .. L(x.usa[1], x.usa[2]) .. (tiene and L(" (ya aplicado)", " (already applied)") or "") .. "|r")
          or (GRIS .. L("En el addon: solo informativo (el addon no calcula nada con esto).", "In the addon: info only (the addon doesn't calculate anything with this).") .. "|r")
        h.item({ texto = Y(BLANCO .. x.n .. "|r  " .. rg .. "\n" .. GRIS .. desc .. "|r\n" .. efecto), chico = true, sangria = 12 })
      end
    end
  end
  if not hay then
    h.nota(Y(GRIS .. L("Aun no tienes perks Legacy en este personaje (o el juego no los muestra). Cuando pongas uno, esta lista y las vistas que afecta se recalculan solas.",
      "You don't have Legacy perks on this character yet (or the game doesn't show them). When you pick one, this list and the views it affects update on their own.") .. "|r"))
  end
  h.nota(Y(GRIS .. L("No hay perk de velocidad a pie en el arbol actual. Los nodos \"Unknown\" llegaran en una actualizacion futura del juego.",
    "There is no walking speed perk in the current tree. The \"Unknown\" nodes will come in a future game update.") .. "|r"))
  -- Legacy Points y certificacion por tus profesiones de fabricar
  for _, f in ipairs(FABRICAR) do
    local r = mias[f.id]
    if r then
      local prox
      for _, u in ipairs({ 150, 225, 300 }) do if r < u then prox = u; break end end
      local txt = prox and L(NOMBRE[f.id] .. " a " .. prox .. ": +1 Legacy Point (llevas " .. r .. ").", NOMBRE[f.id] .. " at " .. prox .. ": +1 Legacy Point (you have " .. r .. ").")
        or L(NOMBRE[f.id] .. ": ya sacaste sus 3 Legacy Points (150, 225 y 300).", NOMBRE[f.id] .. ": you already earned its 3 Legacy Points (150, 225 and 300).")
      h.nota(Y(VERDE .. txt .. "|r"))
      h.nota(Y(GRIS .. L("Con 300: " .. NOMBRE[f.id] .. " Certification (1000 Merchant's Favor) = titulo \"" .. f.titulo .. "\" para toda la cuenta (dato de la beta).",
        "At 300: " .. NOMBRE[f.id] .. " Certification (1000 Merchant's Favor) = \"" .. f.titulo .. "\" title for your whole account (beta data).") .. "|r"))
    end
  end
  if mias[393] then h.nota(Y(GRIS .. "Skinning: " .. WowF.notaSkinningUnaVez() .. "|r")) end
  h.nota(Y(NARANJA .. L("Rangos, números y certificaciones salen de la beta: pueden cambiar, se actualizará en próximas actualizaciones.",
    "Ranks, numbers and certifications come from the beta: they may change, it will be updated in future updates.") .. "|r"))
  h.nota(Y(GRIS .. L("Fuente: ", "Source: ") .. WowF.LEGACY_URL .. "|r"))
end

-- Paso de la ayuda (bienvenida): titulo, icono, texto
function WowF.pasoAyudaLegacy()
  return { L("Profesiones en Forever", "Professions in Forever"), "Interface\\Icons\\INV_Misc_Book_09",
    L(ORO .. "Legacy|r (tecla Y): perks de cuenta. Para profesiones: " .. BLANCO .. "Working Overtime|r (subes mas rapido) y " .. BLANCO .. "Dedicated Study|r (+1 al dia).\n\n"
      .. ORO .. "Certification|r: con 300 y 1000 Merchant's Favor ganas el titulo de la profesion para toda la cuenta.\n\n"
      .. GRIS .. "Otro addon util: SkillUp Forever (CurseForge) muestra en la ventana de profesiones que receta te sube.|r",
      ORO .. "Legacy|r (Y key): account perks. For professions: " .. BLANCO .. "Working Overtime|r (level up faster) and " .. BLANCO .. "Dedicated Study|r (+1 a day).\n\n"
      .. ORO .. "Certification|r: at 300 with 1000 Merchant's Favor you earn the profession title for your whole account.\n\n"
      .. GRIS .. "Another useful addon: SkillUp Forever (CurseForge) shows in the profession window which recipe gives you skill.|r") }
end

-- Skinning: cada criatura se despella una sola vez (notas de la beta del 1-oct)
function WowF.notaSkinningUnaVez()
  return L("Cada criatura se despella UNA sola vez: busca sitios con muchas (notas de la beta, 1-oct).",
    "Each creature can be skinned only ONCE: look for spots with many of them (beta notes, Oct 1).")
end

-- ===== 12-oct: puntos de talento REALES (Legacy "Talented") =====
-- Perk "Talented" (Legacy, Adventure; hechizo del cliente 1225474, 5 rangos): "You gain talent points every level starting at
-- level $s1 instead of starting at level 10, but you still may not have more than 51 total talent points." Cada rango adelanta
-- 1 nivel: con k rangos tienes (nivel - 9 + k) puntos, tope 51 (a 5/5: 26 puntos al nivel 30 en vez de 21).
-- El addon NO adivina el rango: lee del cliente los puntos puestos (suma de los arboles) + los sin gastar; lo que pase de
-- (nivel - 9) son puntos extra. Valores con pcall + WowF.numero (la beta puede devolverlos secretos).
WowF.TALENTED_ID = 1225474
local function num(v)
  if v == nil then return nil end
  if WowF.numero then return tonumber(WowF.numero(v)) end
  if issecretvalue then local ok, s = pcall(issecretvalue, v); if not ok or s then return nil end end
  return tonumber(v)
end
-- Puntos puestos en todos los arboles (nil = el cliente no lo dice con seguridad)
local function puntosPuestos()
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local ok, n = pcall(GetNumTalentTabs)
  n = ok and num(n) or nil
  if not n or n < 1 then return nil end
  local total = 0
  for t = 1, n do
    -- Cliente nuevo: id, nombre, descripcion, icono, PUNTOS...; cliente viejo: nombre, icono, PUNTOS, archivo
    local okT, _, _, d3, _, d5 = pcall(GetTalentTabInfo, t)
    local p = okT and (num(d5) or num(d3)) or nil
    if (not p or p == 0) and GetNumTalents and GetTalentInfo then
      local okN, k = pcall(GetNumTalents, t)
      k = okN and num(k) or nil
      if k then
        local suma = 0
        for i = 1, k do
          local okI, _, _, _, _, r = pcall(GetTalentInfo, t, i)
          suma = suma + (okI and num(r) or 0)
        end
        p = math.max(p or 0, suma)
      end
    end
    if not p then return nil end
    total = total + p
  end
  return total
end

-- { nivel, porNivel, puestos, sinGastar, total, extra, seguro, talented }
--   porNivel = lo que da el nivel sin Legacy (nivel - 9, entre 0 y 51); extra = puntos de mas (0-5) si seguro
function WowF.puntosTalento()
  local okN, nv = pcall(function() return UnitLevel and UnitLevel("player") end)
  local nivel = okN and num(nv) or 1
  local r = { nivel = nivel, porNivel = math.max(0, math.min(51, nivel - 9)), extra = 0, seguro = false,
    talented = tieneHechizo(WowF.TALENTED_ID) }
  local okL, libres = pcall(function() return UnitCharacterPoints and UnitCharacterPoints("player") end)
  libres = okL and num(libres) or nil
  if libres == nil and GetUnspentTalentPoints then -- 12-oct: este cliente puede no traer UnitCharacterPoints
    local okU, u = pcall(GetUnspentTalentPoints); libres = okU and num(u) or nil
  end
  local puestos = puntosPuestos()
  r.puestos, r.sinGastar = puestos, libres
  if puestos and libres then
    r.total = puestos + libres
    r.seguro = true
    -- Adelanto = total - (nivel - 9), sin cortar en 0: al nivel 8 con 5/5 tienes 4 puntos = 5 de adelanto
    if r.total > 0 and r.total < 51 then r.extra = math.max(0, math.min(5, r.total - (nivel - 9))) end
    if r.total >= 51 then r.extra = 0 end
  end
  if not r.seguro and WowF._rangoTalentedTraits then
    local rt = WowF._rangoTalentedTraits()
    if rt then r.extra, r.seguro, r.fuente = rt, true, "traits"; r.total = r.porNivel + rt end
  end
  return r
end
-- Puntos extra seguros (0 si no se pueden leer)
function WowF.extraTalentos(r)
  r = r or WowF.puntosTalento()
  return (r and r.seguro and r.extra) or 0
end
-- Nivel al que te llega el punto idx de la guia (con extra puntos de Legacy)
function WowF.nivelDePunto(idx, extra) return math.max(1, 9 + idx - (extra or 0)) end
-- Puntos que tienes al nivel n (con extra puntos de Legacy), tope 51
function WowF.puntosAlNivel(n, extra) return math.max(0, math.min(51, n - 9 + (extra or 0))) end

-- Nota para el jugador (nil = nada que decir)
function WowF.notaLegacyTalentos(r)
  r = r or WowF.puntosTalento()
  if r.seguro and r.extra > 0 then
    return Y(VERDE .. L("Tienes " .. r.extra .. (r.extra == 1 and " punto de talento extra" or " puntos de talento extra") .. " (Legacy: Talented): vas "
      .. r.extra .. (r.extra == 1 and " punto adelantado" or " puntos adelantado") .. ". Cada punto de la guía te llega " .. r.extra .. (r.extra == 1 and " nivel antes." or " niveles antes."),
      "You have " .. r.extra .. " extra talent point" .. (r.extra == 1 and "" or "s") .. " (Legacy: Talented): you are " .. r.extra .. " point" .. (r.extra == 1 and "" or "s")
      .. " ahead. Each point of the guide comes " .. r.extra .. " level" .. (r.extra == 1 and "" or "s") .. " earlier.") .. "|r")
  end
  if not r.seguro then
    return Y(NARANJA .. L("Puntos extra de Legacy (Talented): el juego aún no nos deja leerlos; los niveles de abajo cuentan 1 punto por nivel desde el 10. Se actualizará.",
      "Extra Legacy talent points (Talented): the game does not let us read them yet; the levels below count 1 point per level from 10. It will be updated.") .. "|r")
  end
  return nil
end

-- ===== 12-oct: rango REAL de cada perk =====
-- 1) C_Traits (config del sistema Legacy 45 -> GetNodeInfo del nodo: ranksPurchased/currentRank); 2) si no, aura del hechizo
--    (C_UnitAuras.GetPlayerAuraBySpellID: solo dice que lo tienes); 3) si no, IsPlayerSpell. Sin rango seguro pero con el perk
--    = rango 1 (el minimo garantizado) y seguro = false: el addon calcula con lo minimo y lo dice. Nada de numeros inventados.
-- Lo que lee el cliente se anota una vez por sesion en WowFExportarDB.diagLegacy (para revisarlo sin pedirle nada al jugador).
local cacheRango, cacheT = {}, -1
local function ahora() local ok, t = pcall(function() return GetTime and GetTime() end); return ok and tonumber(t) or 0 end
local function configLegacy()
  if not (C_Traits and C_Traits.GetConfigIDBySystemID) then return nil end
  local ok, c = pcall(C_Traits.GetConfigIDBySystemID, WowF.LEGACY_SISTEMA)
  c = ok and num(c) or nil
  if c and c > 0 then return c end
  return nil
end
local function rangoNodo(config, p)
  if not (config and p.nodo and C_Traits and C_Traits.GetNodeInfo) then return nil end
  local ok, info = pcall(C_Traits.GetNodeInfo, config, p.nodo)
  if not ok or type(info) ~= "table" then return nil end
  local r = num(info.ranksPurchased) or num(info.currentRank)
  if p.eleccion then
    if not p.entradas then return nil end
    if r == 0 then return 0 end
    local okE, e = pcall(function() return info.activeEntry and info.activeEntry.entryID end)
    e = okE and num(e) or nil
    return e and p.entradas[e] or nil
  end
  return r
end
function WowF._rangoTalentedTraits() return rangoNodo(configLegacy(), POR_ID[WowF.TALENTED_ID]) end
local function tieneAura(id)
  local ok, a = pcall(function() return C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(id) end)
  return ok and type(a) == "table"
end
-- { rango (0..r), seguro, fuente } de un perk por su hechizo
function WowF.legacyRango(id)
  local t = ahora()
  if t ~= cacheT then cacheRango, cacheT = {}, t end
  if cacheRango[id] then return cacheRango[id] end
  local p = POR_ID[id]
  local res = { rango = 0, seguro = false, fuente = "ninguna", max = p and p.r or 1 }
  if p and p.eleccion then
    local pt = WowF.puntosTalento()
    if pt.seguro then res.rango, res.seguro, res.fuente = math.max(0, math.min(p.r, pt.extra)), true, "puntos"
    elseif pt.talented then res.rango, res.fuente = 1, "hechizo" end
    if pt.seguro and pt.fuente == "traits" then res.fuente = "traits" end
  elseif p then
    local r = rangoNodo(configLegacy(), p)
    if r then res.rango, res.seguro, res.fuente = math.max(0, math.min(p.r, r)), true, "traits"
    elseif tieneHechizo(id) or tieneAura(id) then res.rango, res.fuente = 1, "hechizo"
    end
  end
  cacheRango[id] = res
  return res
end
-- Valor del perk a tu rango (0 = no lo tienes), y el resultado de legacyRango
function WowF.legacyValor(id)
  local p, r = POR_ID[id], WowF.legacyRango(id)
  if not p or r.rango < 1 then return 0, r end
  return p.v[r.rango] or 0, r
end
local diagHecho = false
function WowF.legacyDiagnostico()
  if diagHecho or type(WowFExportarDB) ~= "table" then return end
  diagHecho = true
  local d = { config = configLegacy(), perks = {} }
  for _, p in ipairs(PERKS) do local r = WowF.legacyRango(p.id); if r.fuente ~= "ninguna" then d.perks[p.n] = r.rango .. "/" .. p.r .. " " .. r.fuente end end
  local ok, fecha = pcall(function() return date and date("%Y-%m-%d %H:%M") end)
  d.fecha = ok and fecha or nil
  WowFExportarDB.diagLegacy = d
end

-- Working Overtime: veces que hay que fabricar en un paso (estimado prudente). Los puntos naranjas ya suben siempre (1 por punto);
-- lo que pasa de eso son intentos fallidos y se dividen por (1 + %): ahorro menor que el real, nunca mayor.
-- Devuelve veces, materiales (misma forma que ps[6]) y cuantas te ahorras
function WowF.pasoConLegacy(ps)
  local veces, mats = ps[4], ps[6]
  local v = WowF.legacyValor(1225451)
  if not v or v <= 0 or type(veces) ~= "number" then return veces, mats, 0 end
  local puntos = math.max(1, (ps[2] or 0) - (ps[1] or 0))
  if veces <= puntos then return veces, mats, 0 end
  local nuevo = puntos + math.ceil((veces - puntos) / (1 + v / 100))
  if nuevo >= veces then return veces, mats, 0 end
  local m2 = {}
  for i, par in ipairs(mats or {}) do
    local cada = (tonumber(par[2]) or 0) / veces
    m2[i] = { par[1], math.ceil(cada * nuevo - 0.0001) }
  end
  return nuevo, m2, veces - nuevo
end

-- Lineas cortas para otras vistas (nil = no tienes el perk)
function WowF.notaLegacyFavor()
  local v, r = WowF.legacyValor(1225456)
  if v <= 0 then return nil end
  return Y(VERDE .. L("Legacy Performance Bonus " .. r.rango .. "/3: " .. v .. " % de las cajas dan el Favor doble (de media +" .. v .. " % de Favor por caja)",
    "Legacy Performance Bonus " .. r.rango .. "/3: " .. v .. "% of crates give double Favor (on average +" .. v .. "% Favor per crate)")
    .. (r.seguro and "" or L(" (al menos)", " (at least)")) .. ".|r")
end
function WowF.esperaCampamento(min)
  min = tonumber(min) or 60
  local v, r = WowF.legacyValor(1225479)
  if v <= 0 then return min, nil end
  local n = math.floor(min * (100 - v) / 100 + 0.5)
  return n, Y(VERDE .. L(" (Legacy Field Guide " .. r.rango .. "/3: -" .. v .. " %, antes " .. min .. " min)", " (Legacy Field Guide " .. r.rango .. "/3: -" .. v .. "%, was " .. min .. " min)") .. "|r")
end
function WowF.notaLegacySigilo()
  local v, r = WowF.legacyValor(1225477)
  if v <= 0 then return nil end
  return Y(VERDE .. L("Tu Legacy High Alert " .. r.rango .. "/2 tambien te ayuda: ves el sigilo como si tuvieras " .. v .. (v == 1 and " nivel" or " niveles") .. " mas (no en campos de batalla).",
    "Your Legacy High Alert " .. r.rango .. "/2 helps too: you detect stealth as if you were " .. v .. " level" .. (v == 1 and "" or "s") .. " higher (not in battlegrounds).") .. "|r")
end
function WowF.notaLegacyConsumibles()
  local t = {}
  local g, rg = WowF.legacyValor(1225499)
  if g > 0 then t[#t + 1] = L("Gourmand " .. rg.rango .. "/3: el buff de la comida dura " .. g .. " % mas (necesitas menos comida).", "Gourmand " .. rg.rango .. "/3: food buffs last " .. g .. "% longer (you need less food).") end
  local f, rf = WowF.legacyValor(1225475)
  if f > 0 then t[#t + 1] = L("Field Medicine " .. rf.rango .. "/2: Recently Bandaged dura " .. f .. " s menos fuera de mazmorras (vendas mas seguidas).", "Field Medicine " .. rf.rango .. "/2: Recently Bandaged lasts " .. f .. " sec less outside dungeons (bandage more often).") end
  local e = WowF.legacyValor(1225503)
  if e > 0 then t[#t + 1] = L("Reagent Economy: tus habilidades de clase no gastan reagents de vendedor (no los compres).", "Reagent Economy: your class abilities don't use vendor reagents (don't buy them).") end
  if #t == 0 then return nil end
  return Y(VERDE .. "Legacy: " .. table.concat(t, " ") .. "|r")
end
function WowF.notaLegacyDurabilidad()
  local v, r = WowF.legacyValor(1225497)
  if v <= 0 then return nil end
  return L("Legacy Reinforce " .. r.rango .. "/5: pierdes " .. v .. " % menos al morir.", "Legacy Reinforce " .. r.rango .. "/5: you lose " .. v .. "% less when you die.")
end
