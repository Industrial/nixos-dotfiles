-- Forever Leveling Guide: pestana Profesiones por tarjetas (11-oct, maqueta profesiones.html aprobada por Andy).
-- WowF.vistaProfesiones (contrato en CONTRATO.md). Solo dibuja la sub-pestana "Mis profesiones" (mias); las otras
-- (Para vender / Secundarias / Mas) y el paso 1 sin objetivo elegido devuelven nil y el Libro pinta lo de siempre.
-- Usa el kit de wowF_VistaCombate.lua (WowF.vistaKit). Colores de acento: E.tema() (Horde brasa, Alliance azul).
-- Cero Classic: el nivel de personaje de D.caps NO se muestra; el requisito es la habilidad (pideRango, Wowhead /forever).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local unpack = unpack or table.unpack

local function E() return WowF.estilo end
local function C() return (WowF.estilo and WowF.estilo.color) or {} end
local function SIN_DATOS() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end

-- ----- Ayudas (copias de las locales de wowF_Libro.lua, que no se pueden llamar desde aqui) -----
local ICONO = {
  [186] = "Interface\\Icons\\Trade_Mining", [182] = "Interface\\Icons\\Trade_Herbalism", [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  [165] = "Interface\\Icons\\Trade_LeatherWorking", [197] = "Interface\\Icons\\Trade_Tailoring", [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [171] = "Interface\\Icons\\Trade_Alchemy", [202] = "Interface\\Icons\\Trade_Engineering", [333] = "Interface\\Icons\\Trade_Engraving",
  [129] = "Interface\\Icons\\INV_Misc_Bandage_15", [185] = "Interface\\Icons\\INV_Misc_Food_15", [356] = "Interface\\Icons\\INV_FishingPole_02",
}
local ICONO_PROF = "Interface\\Icons\\INV_Misc_Gear_01"
local ICONO_ENTRENADOR = "Interface\\Icons\\INV_Scroll_01"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local SECUNDARIAS = { 185, 129, 356 }
local NOMBRE_FIJO = { [129] = "First Aid", [185] = "Cooking", [356] = "Fishing" }
local RANGO = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local CAPITAL_RAZA = { Human = 1453, Dwarf = 1455, Gnome = 1455, NightElf = 1457, Orc = 1454, Troll = 1454, Tauren = 1456, Scourge = 1458, Undead = 1458 }
local CAPITALES = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }

local function iconoProf(id) return ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO_PROF end
local function nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or NOMBRE_FIJO[id] or tostring(id) end
local function tengo(id) return (GetItemCount and GetItemCount(id, true)) or 0 end
local function obj(id)
  local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  if o then return o[1], o[2], o[3] end
  return tostring(id), 1, ""
end
local function iconoObj(ic, id)
  -- 12-oct: primero el icono que da el cliente para ESE id; los datos solo de respaldo
  if id and WowF.iconoObjeto then local t = WowF.iconoObjeto(id, ic); if t then return t end end
  if ic and ic ~= "" then return "Interface\\Icons\\" .. ic end
  local t
  if id and C_Item and C_Item.GetItemIconByID then t = C_Item.GetItemIconByID(id) end
  if not t and id and GetItemIcon then t = GetItemIcon(id) end
  return t
end
local function trozos(t)
  local res = {}
  for x in (tostring(t or "") .. " · "):gmatch("(.-) · ") do if x ~= "" then table.insert(res, x) end end
  return res
end
-- Rango y maximo de una profesion (por id; si no, por nombre en la lista de habilidades)
local function habilidad(id)
  if WowF.rangoProfesion then
    local ok, r, m = pcall(WowF.rangoProfesion, id)
    if ok and r then return r, m end
  end
  if not GetNumSkillLines or not GetSkillLineInfo then return nil end
  local buscado = nombreProf(id):lower()
  for i = 1, GetNumSkillLines() do
    local n, esCab, _, rango, _, _, maximo = GetSkillLineInfo(i)
    if n and not esCab and n:lower() == buscado then return rango, maximo end
  end
  return nil
end
local function pideRango(id, tope)
  local t = WowFDatos and WowFDatos.pideRango and WowFDatos.pideRango[id]
  return t and tonumber(t[tope])
end
local function mapaAqui() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end
-- Entrenador de tu faccion que ensena ese tope: el del mapa donde estas, luego la capital de tu raza, luego otra capital.
-- Los de posicion aproximada no se eligen (2.o valor = el unico que hay, sin posicion de Forever).
local function entrenadorPara(id, cap)
  local lista = WowFDatos and WowFDatos.entrenadores and WowFDatos.entrenadores[id]
  if not lista then return nil end
  local fac = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  local aqui = mapaAqui()
  local _, raza = UnitRace and UnitRace("player")
  local casa = CAPITAL_RAZA[raza or ""]
  local px, py
  if aqui and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, aqui, "player")
    if ok and pos then px, py = (pos.x or 0) * 100, (pos.y or 0) * 100 end
  end
  local mejor, mp, sinPos, sp
  for _, e in ipairs(lista) do
    if (e[5] == fac or e[5] == "N") and (cap <= 75 or (e[6] or 0) > cap - 75) then
      local pr = 4
      if e[2] == aqui then pr = 0 + (px and (math.sqrt((e[3] - px) ^ 2 + (e[4] - py) ^ 2) / 1000) or 0)
      elseif e[2] == casa then pr = 1
      elseif CAPITALES[e[2]] then pr = 2 end
      if WowF.esAproximado and WowF.esAproximado(e) then
        if not sp or pr < sp then sinPos, sp = e, pr end
      elseif not mp or pr < mp then mejor, mp = e, pr end
    end
  end
  return mejor, (not mejor) and sinPos or nil
end
local function marcarEntrenador(e, prof)
  if not e then return end
  if WowF.esAproximado and WowF.esAproximado(e) and WowF.marcarEntrenador then WowF.marcarEntrenador(e, prof); return end
  if WowF.marcar then WowF.marcar({ m = e[2], x = e[3], y = e[4], n = e[1] .. L(" (entrenador de ", " (") .. prof .. L(")", " trainer)"), z = e[7], lugar = true }) end
end
local function farmeo(nombre) if SlashCmdList and SlashCmdList.WOWF then SlashCmdList.WOWF("farmeo " .. nombre) end end
local function miFaccion()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return 1 elseif f == "Alliance" then return 2 end
  return 0
end
-- "Peacebloom, Silverleaf, Earthroot" -> "Peacebloom y Silverleaf" (los dos primeros, como la maqueta)
local function dosNodos(t)
  local n = {}
  for x in tostring(t or ""):gmatch("[^,]+") do x = x:gsub("^%s+", ""):gsub("%s+$", ""); if x ~= "" then table.insert(n, x) end end
  if #n == 0 then return "" end
  if #n == 1 then return n[1] end
  return n[1] .. L(" y ", " and ") .. n[2]
end

-- 13-oct (auditoria de profesiones, Andy: "le mando a craftear 25 y tuvo que craftear mas"; "no lo lleva a ningun lado"):
-- la cuenta de cada receta sale de la probabilidad real de subir (amarillo/gris de la receta, Working Overtime de Legacy) y se
-- rehace con TU rango; "seguras" = las que bastan a 9 de cada 10 jugadores. El clic te lleva a lo primero que te falta.
do
  local function Yt(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
  local function decir(es, en) print(Yt("|cff33ccffForever Guide:|r " .. L(es, en))) end
  local function lado() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end
  -- vendedores {nombre, mapa, x, y, faccion, zona} de tu faccion (o neutrales), el mas cercano primero
  local function vendedorMio(lista)
    local r = {}
    for _, v in ipairs(lista or {}) do
      if v[5] == lado() or v[5] == "N" then table.insert(r, { npc = v[1], m = v[2], x = v[3], y = v[4], z = v[6] }) end
    end
    if #r == 0 then return nil end
    if WowF._bisMasCerca then local ok, v = pcall(WowF._bisMasCerca, r); if ok and v then return v end end
    return r[1]
  end
  local function ir(destino, sub)
    if WowF.marcarNPC and destino.npc then pcall(WowF.marcarNPC, { n = destino.npc, sub = sub }) end
    if WowF.viajeA then
      local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true })
      if ok and hecho then return true end
    end
    if WowF.marcar then WowF.marcar({ m = destino.m, x = destino.x, y = destino.y, n = destino.n, z = destino.z, lugar = true }); return true end
    return false
  end
  local function irVendedor(v, que)
    decir(que .. ": lo vende " .. v.npc .. " en " .. (v.z or "?") .. " (" .. v.x .. ", " .. v.y .. "). Te llevo allí.",
      que .. ": sold by " .. v.npc .. " in " .. (v.z or "?") .. " (" .. v.x .. ", " .. v.y .. "). Taking you there.")
    local d = { m = v.m, x = v.x, y = v.y, z = v.z, npc = v.npc, n = Yt(v.npc .. " (" .. que .. ")") }
    d.final = { texto = Yt(L("Compra " .. que .. " a " .. v.npc, "Buy " .. que .. " from " .. v.npc)), titulo = v.npc, corto = v.npc, detalle = "",
      llegada = Yt(L("Compra " .. que .. " a " .. v.npc .. ".", "Buy " .. que .. " from " .. v.npc .. ".")), npc = v.npc }
    return ir(d, "|cffffd100" .. Yt(que) .. "|r")
  end
  local function nombreObjeto(id)
    local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
    if o then return o[1] end
    local n = GetItemInfo and GetItemInfo(id)
    return n or ("#" .. tostring(id))
  end
  local function areaDe(id)
    if not WowF.mejorAreaMobs then return nil end
    local ok, a = pcall(WowF.mejorAreaMobs, id)
    return ok and a or nil
  end

  -- Cuantas veces fabricar de 'desde' a 'hasta' empezando en tu rango r0.
  -- Devuelve media, seguras, materiales {{id, n}} para las seguras, cuantas te ahorra Legacy
  function WowF.cuentaPaso(ps, desde, hasta, r0)
    local a = math.max(desde or ps[1] or 0, r0 or 0)
    local z = hasta or ps[2] or a
    if a >= z then return 0, 0, {}, 0 end
    local am, gr = tonumber(ps[9]), tonumber(ps[10])
    if not am or not gr or gr <= am then
      -- sin colores de la receta: lo de los datos, en proporcion al tramo
      local veces, mats, ahorro = ps[4], ps[6], 0
      if WowF.pasoConLegacy then veces, mats, ahorro = WowF.pasoConLegacy(ps) end
      local f = (z - a) / math.max(1, (ps[2] or z) - (ps[1] or a))
      local seg = math.ceil((tonumber(ps[13]) or tonumber(veces) or 0) * f)
      local m2 = {}
      for i, par in ipairs(mats or {}) do m2[i] = { par[1], math.ceil((tonumber(par[2]) or 0) * f) } end
      return math.ceil((tonumber(veces) or 0) * f), seg, m2, ahorro
    end
    local v = WowF.legacyValor and WowF.legacyValor(1225451) or 0
    local k = 1 + (tonumber(v) or 0) / 100
    local media, var, media0, var0 = 0, 0, 0, 0
    for s = a, z - 1 do
      local p = 1
      if s >= am then p = math.max(0.04, (gr - s) / (gr - am)) end
      media0 = media0 + 1 / p
      var0 = var0 + (1 - p) / (p * p)
      media = media + 1 + (1 / p - 1) / k
      var = var + (1 - p) / (p * p) / (k * k)
    end
    local seg = math.ceil(media + 1.28 * math.sqrt(var) - 0.0001)
    local seg0 = math.ceil(media0 + 1.28 * math.sqrt(var0) - 0.0001)
    local mats = {}
    for i, par in ipairs(ps[11] or {}) do mats[i] = { par[1], (tonumber(par[2]) or 0) * seg } end
    return math.ceil(media - 0.0001), seg, mats, math.max(0, seg0 - seg)
  end

  -- 13-oct (Andy: "que se entienda como leer los numeros"): la frase del paso y su explicacion, la misma en tarjeta, Libro y chat.
  -- Sin "hasta N" para cantidades (se confundia con el rango). Devuelve linea, explicacion, enCurso, puntos.
  function WowF.textoPaso(ps, a, z, r0, veces, seguras)
    local receta = ps[7] or "?"
    r0 = r0 or 0
    if r0 >= z then return L("Hecho: ", "Done: ") .. receta, nil, false, 0 end
    local desde = math.max(a, r0)
    local enCurso = desde > a
    local puntos = z - desde
    local cuanto = (seguras > veces) and L("unas " .. veces, "about " .. veces) or tostring(veces)
    local linea = enCurso and L("Te faltan " .. cuanto .. " x ", cuanto .. " more x ") .. receta
      or L("Fabrica " .. cuanto .. " x ", "Craft " .. cuanto .. " x ") .. receta
    local ex = L("De " .. desde .. " a " .. z .. " = " .. puntos .. (puntos == 1 and " punto" or " puntos"),
      "From " .. desde .. " to " .. z .. " = " .. puntos .. (puntos == 1 and " point" or " points"))
    local am, gr = tonumber(ps[9]), tonumber(ps[10])
    if not am or not gr or gr <= am then
      ex = ex .. L(". Cantidad aproximada: aún no hay colores de esta receta en WoW Forever.", ". Approximate amount: no recipe colors from WoW Forever yet.")
    elseif veces <= puntos and seguras <= veces then
      ex = ex .. L(": cada " .. receta .. " te sube 1 punto.", ": each " .. receta .. " gives you 1 point.")
    else
      ex = ex .. L(". Desde " .. am .. " la receta sale amarilla y a veces no sube: de media son " .. veces .. ".",
        ". From " .. am .. " the recipe turns yellow and sometimes gives no point: about " .. veces .. " on average.")
    end
    if seguras > veces then ex = ex .. L(" Ten material para " .. seguras .. " por si tienes mala suerte.", " Have materials for " .. seguras .. " in case of bad luck.") end
    return linea, ex, enCurso, puntos
  end

  -- De donde sale un material: texto y que hacer al hacer clic (nil = sin datos)
  function WowF.origenMaterial(id, prof)
    local D = WowFDatos or {}
    local f = D.matFab and D.matFab[prof] and D.matFab[prof][id]
    if f then
      local t = {}
      for _, r in ipairs(f[3] or {}) do table.insert(t, r[2] .. " " .. nombreObjeto(r[1])) end
      return L("fabrícalo tú con tu profesión: ", "craft it yourself: ") .. table.concat(t, " + ") .. L(" cada uno", " each"),
        { tipo = "fab", reag = f[3] }
    end
    local o = D.matOrigen and D.matOrigen[id]
    local v = o and vendedorMio(o.vend)
    if v then return L("lo vende ", "sold by ") .. v.npc .. L(" en ", " in ") .. (v.z or "?"), { tipo = "vend", v = v } end
    local t = o and o.t or ""
    if t:find("P") then return L("se despelleja (Skinning)", "skinned (Skinning)"), { tipo = "piel" } end
    if t:find("R") then return L("se recoge (Herbalism)", "gathered (Herbalism)"), { tipo = "farm", prof = "Herbalism" } end
    if t:find("M") then return L("se mina (Mining)", "mined (Mining)"), { tipo = "farm", prof = "Mining" } end
    local a = areaDe(id)
    if a then
      local b = a.bichos and a.bichos[1]
      return L("lo sueltan mobs", "dropped by mobs") .. (b and (": " .. b.nombre .. L(" (niv ", " (lvl ") .. b.min .. "-" .. b.max .. ")") or "") .. L(" en ", " in ") .. (a.zona or "?"),
        { tipo = "mobs", id = id }
    end
    -- 13-oct: sin area de tu nivel (o sin posicion) pero con bichos que lo sueltan en los datos de Forever: el clic igual lleva a la ruta de bichos
    -- (que elige el area o explica que aun no hay datos), nunca a otra profesion.
    if WowF.hayAreaMobs and WowF.hayAreaMobs(id) then return L("lo sueltan mobs", "dropped by mobs"), { tipo = "mobs", id = id } end
    if t:find("B") then return L("botín de mobs o casa de subastas", "mob loot or auction house"), nil end
    if t:find("C") then return L("sale de contenedores (cajas, bolsas)", "found in containers"), nil end
    return SIN_DATOS(), nil
  end

  -- De donde sale la receta del paso: texto y vendedor (si lo hay)
  function WowF.origenReceta(ps)
    local letra = ps[14] or ""
    if letra == "A" then return L("la sabes desde que aprendes la profesión", "known when you learn the profession") end
    if letra == "E" then return L("la enseña tu entrenador de la profesión", "taught by your profession trainer") end
    if letra == "V" then
      local D = WowFDatos or {}
      local lista = D.objetivoProf and D.objetivoProf.vend and D.objetivoProf.vend[ps[8]]
      local v = vendedorMio(lista)
      if not v and ps[12] and ps[12] ~= 0 and D.matOrigen and D.matOrigen[ps[12]] then v = vendedorMio(D.matOrigen[ps[12]].vend) end
      local patron = (ps[12] and ps[12] ~= 0) and nombreObjeto(ps[12]) or (ps[7] or "?")
      if v then return L("compra ", "buy ") .. patron .. L(" a ", " from ") .. v.npc .. L(" en ", " in ") .. (v.z or "?"), v, patron end
      return patron .. L(" la vende un vendedor; ", " is sold by a vendor; ") .. SIN_DATOS(), nil, patron
    end
    if letra == "B" then
      local patron = (ps[12] and ps[12] ~= 0) and nombreObjeto(ps[12]) or (ps[7] or "?")
      return patron .. L(": botín de mobs; búscala en la casa de subastas", ": mob loot; look for it in the auction house"), nil, patron
    end
    local t = tostring(ps[5] or "")
    return t ~= "" and WowF.T(t) or SIN_DATOS()
  end

  -- Recetas que ya sabes: se apuntan al abrir la ventana de la profesion (por id de la receta y por nombre), por personaje.
  -- IsSpellKnown no sirve para recetas de profesion en todos los clientes: true = la sabes, nil = no se sabe.
  local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
  local function sabidas()
    if type(WowFExportarDB) ~= "table" then return {} end
    WowFExportarDB.recetasSabidas = WowFExportarDB.recetasSabidas or {}
    local k = clavePj()
    WowFExportarDB.recetasSabidas[k] = WowFExportarDB.recetasSabidas[k] or {}
    return WowFExportarDB.recetasSabidas[k]
  end
  local function leerRecetas()
    local t = sabidas()
    if C_TradeSkillUI and type(C_TradeSkillUI.GetAllRecipeIDs) == "function" then
      local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
      if ok and type(ids) == "table" then
        for _, id in ipairs(ids) do
          local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
          if ok2 and type(info) == "table" and info.learned ~= false then t[id] = true; if type(info.name) == "string" then t[info.name] = true end end
        end
        return
      end
    end
    if type(GetNumTradeSkills) == "function" and type(GetTradeSkillInfo) == "function" then
      local ok, n = pcall(GetNumTradeSkills)
      for i = 1, (ok and tonumber(n)) or 0 do
        local ok2, nombre, tipo = pcall(GetTradeSkillInfo, i)
        if ok2 and type(nombre) == "string" and tipo ~= "header" and tipo ~= "subheader" then
          t[nombre] = true
          if type(GetTradeSkillRecipeLink) == "function" then
            local ok3, enl = pcall(GetTradeSkillRecipeLink, i)
            local sp = ok3 and type(enl) == "string" and tonumber(enl:match("enchant:(%d+)") or enl:match("trade:[^:]*:?(%d+)") or "")
            if sp then t[sp] = true end
          end
        end
      end
    end
  end
  WowF._leerRecetas = leerRecetas
  if CreateFrame then
    local vigia = CreateFrame("Frame")
    local agrupado
    for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do pcall(vigia.RegisterEvent, vigia, ev) end
    vigia:SetScript("OnEvent", function()
      agrupado = agrupado or (WowF.agrupar and WowF.agrupar(leerRecetas, 0.5)) or leerRecetas
      pcall(agrupado)
    end)
  end
  local function sabesReceta(ps)
    local spell = ps[8]
    if spell and IsSpellKnown then local ok, s = pcall(IsSpellKnown, spell); if ok and s then return true end end
    local t = sabidas()
    if (spell and t[spell]) or (ps[7] and t[ps[7]]) then return true end
    return nil
  end
  local function siYaLaSabes()
    decir("Si ya la sabes, abre una vez la ventana de tu profesión y la guía lo recordará.", "If you already know it, open your profession window once and the guide will remember.")
  end

  function WowF.decirPaso(txt) decir(txt, txt) end

  function WowF.ayudaPasoReceta(tt, s)
    local ps = s.ps or {}
    tt:AddLine(s.b, 1, 0.82, 0.48, true)
    if s.nota then tt:AddLine(s.nota, 0.85, 0.82, 0.76, true) end
    if (s.seguras or 0) > (s.veces or 0) then
      tt:AddLine(L("Subir es al azar: cuanto más alto tu rango, más veces falla. De media " .. s.veces .. "; con " .. s.seguras .. " llegan 9 de cada 10 jugadores.",
        "Skill-ups are random: the higher your rank, the more often it fails. About " .. s.veces .. " on average; " .. s.seguras .. " is enough for 9 out of 10 players."), 0.64, 0.6, 0.55, true)
    end
    if (s.ahorro or 0) > 0 then tt:AddLine(L("Legacy Working Overtime: " .. s.ahorro .. " menos", "Legacy Working Overtime: " .. s.ahorro .. " fewer"), 0.49, 0.77, 0.35, true) end
    if #(s.mats or {}) > 0 then
      tt:AddLine(L("Material para " .. s.seguras .. ":", "Materials for " .. s.seguras .. ":"), 0.85, 0.82, 0.76, true)
      for _, m in ipairs(s.mats) do
        local tn = tengo(m[1])
        local col = (tn >= m[2]) and "|cff7cc45a" or "|cffd9d1c2"
        local origen = WowF.origenMaterial(m[1], s.prof)
        tt:AddLine(col .. "· " .. m[2] .. " " .. nombreObjeto(m[1]) .. L(" (tienes " .. tn .. ")", " (you have " .. tn .. ")") .. "|r |cffa39a8c— " .. origen .. "|r", 1, 1, 1, true)
      end
    end
    local sabe = sabesReceta(ps)
    if sabe then tt:AddLine(L("Receta: ya la sabes", "Recipe: you already know it"), 0.49, 0.77, 0.35, true)
    else tt:AddLine(L("Receta: ", "Recipe: ") .. (WowF.origenReceta(ps)), 0.64, 0.6, 0.55, true) end
    tt:AddLine(L("Clic: te llevo a lo primero que te falta", "Click: I take you to the first thing you're missing"), 0.49, 0.77, 0.35, true)
  end

  -- Clic: explica en el chat lo que hace falta y te lleva a lo primero que falta
  function WowF.irPasoReceta(s, nombre)
    local ps = s.ps or {}
    local receta = ps[7] or "?"
    if s.b then WowF.decirPaso(s.b .. "." .. (s.nota and (" " .. s.nota) or "")) end
    -- 1) la receta
    if not sabesReceta(ps) then
      local txt, v, patron = WowF.origenReceta(ps)
      if (ps[14] == "E" or (ps[14] ~= "A" and ps[14] ~= "V" and ps[14] ~= "B")) and s.e then
        decir("Primero aprende " .. receta .. " con tu entrenador. Te llevo allí.", "First learn " .. receta .. " from your trainer. Taking you there.")
        marcarEntrenador(s.e, nombre); siYaLaSabes(); return true
      elseif v and tengo(ps[12] or 0) > 0 then
        decir("Tienes " .. patron .. " en las bolsas: úsalo para aprender la receta.", "You have " .. patron .. " in your bags: use it to learn the recipe.")
      elseif v then local r = irVendedor(v, patron); siYaLaSabes(); return r
      elseif ps[14] ~= "A" then decir("Receta: " .. txt .. ".", "Recipe: " .. txt .. ".") end
    end
    -- 2) los materiales: el primero que no tienes
    for _, m in ipairs(s.mats or {}) do
      local tn = tengo(m[1])
      if tn < m[2] then
        local falta = m[2] - tn
        local mat = nombreObjeto(m[1])
        local txt, acc = WowF.origenMaterial(m[1], s.prof)
        decir("Te faltan " .. falta .. " " .. mat .. ": " .. txt .. ".", "You need " .. falta .. " more " .. mat .. ": " .. txt .. ".")
        if acc and acc.tipo == "fab" then
          -- se fabrica: ir a por su primer ingrediente que falte
          for _, r in ipairs(acc.reag or {}) do
            local nr = r[2] * falta - tengo(r[1])
            if nr > 0 then
              local t2, a2 = WowF.origenMaterial(r[1], s.prof)
              decir("Para eso te faltan " .. nr .. " " .. nombreObjeto(r[1]) .. ": " .. t2 .. ".", "For that you need " .. nr .. " more " .. nombreObjeto(r[1]) .. ": " .. t2 .. ".")
              acc = a2; mat = nombreObjeto(r[1])
              break
            end
          end
          if acc and acc.tipo == "fab" then return true end
        end
        if not acc then return false end
        if acc.tipo == "vend" then return irVendedor(acc.v, mat) end
        if acc.tipo == "piel" and WowF.irAreaMobs then WowF.irAreaMobs("piel"); return true end
        if acc.tipo == "mobs" and WowF.irAreaMobs then WowF.irAreaMobs(acc.id); return true end
        if acc.tipo == "farm" then farmeo(acc.prof); return true end
        return false
      end
    end
    decir("Tienes todo: abre la profesión y fabrica.", "You have everything: open the profession and craft.")
    return true
  end
end

-- ----- Pasos de una profesion: rango con el entrenador + tramos (farmeo o recetas), en orden -----
local function pasosDe(id)
  local D = WowFDatos or {}
  local nombre = nombreProf(id)
  local rango, maximo = habilidad(id)
  local r0 = rango or 0
  local lista = {}
  local antes = 0
  for _, cap in ipairs(D.caps or {}) do
    local tope = cap[2]
    local e, eSinPos = entrenadorPara(id, tope)
    local exige = pideRango(id, tope)
    local hecho = (maximo and maximo >= tope) and true or false
    local b
    if hecho then b = L("Aprendida", "Learned")
    elseif e or eSinPos then
      b = L("Con tu entrenador", "With your trainer") .. (exige and L(", pide " .. nombre .. " " .. exige, ", requires " .. nombre .. " " .. exige) or "")
    else b = SIN_DATOS() end
    table.insert(lista, { tipo = "rango", tope = tope, a = RANGO[tope] or tostring(tope), b = b, hecho = hecho, icono = iconoProf(id), e = e, eSinPos = eSinPos,
      ahoraTxt = L("aprende ", "learn ") .. (RANGO[tope] or tostring(tope)) .. L(" con tu entrenador", " with your trainer") })
    local alguno = false
    local fz = WowFFarmeo and WowFFarmeo[id]
    if D.recoleccion and D.recoleccion[id] and fz and fz.tramos then
      for _, tr in ipairs(fz.tramos) do
        if tr.b > antes and tr.a < tope then
          alguno = true
          local a, z = math.max(tr.a, antes), math.min(tr.b, tope)
          table.insert(lista, { tipo = "farm", desde = a, hasta = z, b = dosNodos(tr.nodos), nodos = tr.nodos, icono = iconoProf(id), hecho = r0 >= z,
            zona = tr.zonas and tr.zonas[1] and tr.zonas[1].n, ahoraTxt = dosNodos(tr.nodos) })
        end
      end
    elseif D.pasos and D.pasos[id] then
      for _, ps in ipairs(D.pasos[id]) do
        if ps[1] < tope and ps[2] > antes then
          alguno = true
          local _, _, oic = obj(ps[3])
          local receta = ps[7] or "?"
          -- 13-oct: el tramo se corta en el tope (antes "68 a 76" salia dos veces) y la cuenta se rehace con tu rango
          -- (probabilidad real de subir + Legacy Working Overtime: WowF.cuentaPaso)
          local a, z = math.max(ps[1], antes), math.min(ps[2], tope)
          local veces, seguras, matsL, ahorro = WowF.cuentaPaso(ps, a, z, (r0 >= z) and a or r0)
          -- 13-oct: tramo ya empezado (rango dentro) = "te faltan" desde TU rango (antes la cantidad del tramo entero, fija)
          -- la frase y su explicacion (cuantos puntos, por que hay mas fabricaciones, material de sobra): WowF.textoPaso
          local linea, nota, enCurso, puntos = WowF.textoPaso(ps, a, z, r0, veces, seguras)
          table.insert(lista, { tipo = "receta", desde = a, hasta = z, ps = ps, prof = id, veces = veces, seguras = seguras, ahorro = ahorro, enCurso = enCurso, nota = nota, puntos = puntos,
            b = linea,
            icono = (ps[3] ~= 0) and iconoObj(oic, ps[3]) or iconoProf(id),
            item = (ps[3] ~= 0) and ps[3] or nil, mats = matsL, aprende = tostring(ps[5] or ""), hecho = r0 >= z, e = e, ahoraTxt = L("fabrica ", "craft ") .. receta })
        end
      end
    end
    if not alguno then
      local t = D.tramos and D.tramos[id] and trozos(D.tramos[id][tope])[1]
      if t and t ~= "" then table.insert(lista, { tipo = "texto", desde = antes, hasta = tope, b = t, icono = iconoProf(id), hecho = r0 >= tope, ahoraTxt = t }) end
    end
    antes = tope
  end
  -- El que toca ahora: el primero sin hacer
  local cur
  for i, s in ipairs(lista) do if not s.hecho then cur = i; break end end
  return lista, cur, rango, maximo
end
WowF.pasosProfesion = pasosDe -- para las pruebas: los pasos con tu rango de ahora

-- ----- Mejor sitio ahora: por tipo de profesion, siempre con datos de Forever -----
local function zonaFarmeo(prof, rango)
  local datos = WowFFarmeo and WowFFarmeo[prof]
  if not datos or not datos.tramos or #datos.tramos == 0 then return nil end
  local tramo = datos.tramos[#datos.tramos]
  for _, t in ipairs(datos.tramos) do if (rango or 0) < t.b then tramo = t; break end end
  local fac = miFaccion()
  local nivel = UnitLevel and UnitLevel("player") or 1
  local aptas = {}
  for _, z in ipairs(tramo.zonas or {}) do if (z.f == 0 or z.f == fac) and nivel >= (z.d or 0) - 3 then table.insert(aptas, z) end end
  if #aptas == 0 then
    for _, z in ipairs(tramo.zonas or {}) do if z.f == 0 or z.f == fac then table.insert(aptas, z) end end
    table.sort(aptas, function(a, b) return (a.d or 0) < (b.d or 0) end)
  end
  local aqui = mapaAqui()
  local mejor = aptas[1]
  for _, z in ipairs(aptas) do if z.m == aqui then mejor = z; break end end
  return mejor, tramo
end
local MATERIAL_DE = { [164] = 186, [202] = 186, [171] = 182 } -- de donde salen los materiales de las que fabrican
local function sitioAhora(id, rango)
  local nombre = nombreProf(id)
  local aqui = mapaAqui()
  local function deFarmeo(prof, prefijo)
    local r = (prof == id) and rango or (habilidad(prof) or rango)
    local z, tramo = zonaFarmeo(prof, r)
    if not z then return nil end
    local sub = (prefijo or "") .. dosNodos(tramo.nodos) .. "."
    if z.m == aqui then sub = sub .. L(" Estás en la zona.", " You are in the zone.") end
    return { zona = z.n, sub = sub, boton = L("Ruta de farmeo", "Farming route"), fn = function() farmeo(nombreProf(prof)) end }
  end
  local function deBichos(clave, fnIr, prefijo)
    if not WowF.mejorAreaMobs then return nil end
    local ok, a = pcall(WowF.mejorAreaMobs, clave)
    if not ok or type(a) ~= "table" then return nil end
    local sub = (prefijo or "") .. L("Mata: ", "Kill: ") .. ((WowF._lineaBichos and WowF._lineaBichos(a, 3)) or "") .. "."
    if a.m == aqui then sub = sub .. L(" Estás en la zona.", " You are in the zone.") end
    if a.lejos then sub = sub .. L(" Queda LEJOS: en tu continente aún no hay datos de tu nivel; se actualizará.", " It is FAR: no data for your level on your continent yet; it will be updated.") end
    return { zona = a.zona, sub = sub, boton = L("Ruta de farmeo", "Farming route"), fn = fnIr }
  end
  if id == 182 or id == 186 then return deFarmeo(id) end
  if id == 393 or id == 165 then return deBichos("piel", function() WowF.irAreaMobs("piel") end) end
  if id == 197 then return deBichos("tela", function() WowF.irAreaMobs("tela") end) end
  if id == 185 or id == 129 then
    local mat
    if WowF.materialSecundaria then
      local okM, m = pcall(WowF.materialSecundaria, id)
      if okM then mat = m end
    end
    local clave = mat or (id == 129 and "tela") or nil
    if not clave then return nil end
    local pref = mat and (obj(mat) .. ": ") or nil
    return deBichos(clave, function() if WowF.areaSecundaria then WowF.areaSecundaria(id) end end, pref)
  end
  if id == 356 then
    local pesca = WowFMobs and WowFMobs.pesca
    if not pesca or not next(pesca) then return nil end
    local zonaAqui = (GetRealZoneText and GetRealZoneText()) or ""
    local mejor
    for pid, zonas in pairs(pesca) do
      for _, z in ipairs(zonas) do
        local enMiZona = z[1] == zonaAqui
        local punt = (enMiZona and 1000 or 0) + (z[2] or 0)
        if not mejor or punt > mejor.punt then mejor = { punt = punt, zona = z[1], pct = z[2], id = pid, aqui = enMiZona } end
      end
    end
    if not mejor then return nil end
    local sub = obj(mejor.id) .. ": " .. tostring(mejor.pct) .. L(" % de cada 100 pescas.", " % out of 100 catches.")
    if mejor.aqui then sub = sub .. L(" Estás en la zona.", " You are in the zone.") end
    return { zona = mejor.zona, sub = sub }
  end
  if MATERIAL_DE[id] then return deFarmeo(MATERIAL_DE[id], L("Materiales: ", "Materials: ")) end
  return nil
end

-- ----- La vista -----
local vista -- { marco, kit }

local function idsLista(p)
  local ids, vistos = {}, {}
  for _, id in ipairs(p.ids or {}) do if not vistos[id] then vistos[id] = true; table.insert(ids, id) end end
  for _, id in ipairs(SECUNDARIAS) do if not vistos[id] then vistos[id] = true; table.insert(ids, id) end end
  return ids
end
local function elegida(ids)
  local g = WowFExportarDB and WowFExportarDB.profVista
  for _, id in ipairs(ids) do if id == g then return id end end
  for _, id in ipairs(ids) do if habilidad(id) then return id end end
  return ids[1]
end
local function redibujar(ctx) if ctx and ctx.redibujar then ctx.redibujar() end end

local function barra(k, p, ancho, ctx, activa)
  local ETQ = { oro = L("Para vender", "To sell"), fabricar = L("Fabricarte equipo", "Craft your gear"), pvp = L("Para PvP", "For PvP") }
  k:seg(0, 0, { { "mias", L("Mis profesiones", "My professions") }, { "objetivo", ETQ[p.objetivo] or L("Qué hacer", "What to do") },
    { "secundarias", L("Secundarias", "Secondary") }, { "cajas", L("Cajas y favor", "Crates & Favor") }, { "campamento", L("Campamento", "Camping") }, { "reputacion", L("Reputación", "Reputation") }, { "legacy", L("Legacy", "Legacy") }, { "mas", L("Entrenadores", "Trainers") } }, activa or "mias", function(c) if ctx and ctx.ponerSub then ctx.ponerSub(c) end end)
  -- 12-oct (Andy: "esta escondido, casi ni se ve"): el objetivo va en una tarjeta propia, a lo ancho y siempre a la vista,
  -- con los tres botones grandes; el elegido en estandarte
  local y, h = 38, 64
  k:tarjeta(0, y, ancho, h, "principal")
  k:rotulo(16, y + 12, L("¿Para qué quieres tus profesiones?", "What do you want your professions for?"))
  k:texto(16, y + 32, L("Cambia lo que te decimos aprender, fabricar y vender.", "It changes what we tell you to learn, craft and sell."), { tam = 12, color = C().tenue, ancho = ancho - 420 })
  local ETQ_OBJ = { fabricar = L("Fabricarme equipo", "Craft my gear"), oro = L("Ganar oro", "Make gold"), pvp = L("PvP", "PvP") }
  local AYUDA = { fabricar = L("Profesiones para hacerte tu propia armadura y armas mientras subes.", "Professions to make your own armor and weapons while leveling."),
    oro = L("Las que más se venden en la casa de subastas.", "The ones that sell best at the auction house."),
    pvp = L("Las que dan ventaja contra otros jugadores.", "The ones that give you an edge against other players.") }
  local orden = WowF.ORDEN_OBJETIVOS or { "fabricar", "oro", "pvp" }
  local x = ancho - 14
  for i = #orden, 1, -1 do
    local o = orden[i]
    local activo = p.objetivo == o
    local _, w = k:boton(x, y + 15, (activo and "» " or "") .. (ETQ_OBJ[o] or o), activo and "estandarte" or "secundario", false, function()
      if WowF.elegirObjetivo and not activo then WowF.elegirObjetivo(o); redibujar(ctx) end
    end, { derecha = true, minimo = 112, ayuda = AYUDA[o] })
    x = x - (w or 112) - 8
  end
  y = y + h
  return y
end

-- Tarjeta de la lista (izquierda)
local LISTA_W = 272
local function tarjetaLista(k, id, y, on, p, ctx)
  local lista, cur, rango, maximo = pasosDe(id)
  local tm = (E().tema and E().tema()) or {}
  local acento = tm.linea or C().brasa
  local h = 70
  local t
  if on then
    t = k:tarjeta(0, y, LISTA_W, h, nil, WowF.vistaKit.AHORA_FONDO, acento)
    k:franja(t, acento)
  elseif rango then
    t = k:tarjeta(0, y, LISTA_W, h)
  else
    t = k:tarjeta(0, y, LISTA_W, h, nil, WowF.vistaKit.CASILLA)
  end
  k:icono(12, y + 13, 44, iconoProf(id), nil, not rango)
  local nombre = nombreProf(id)
  local tx, tw = 68, LISTA_W - 68 - 12
  k:texto(tx, y + 10, nombre, { tam = 14, peso = "negrita", color = rango and C().texto or WowF.vistaKit.LUEGO })
  local yy
  if rango then
    k:texto(0, 0, rango .. "/" .. (maximo or "?"), { tam = 14, peso = "negrita", color = C().texto, punto = { "TOPRIGHT", k.marco, "TOPLEFT", LISTA_W - 12, -(y + 10) } })
    k:barra(tx, y + 31, tw, rango, maximo or 1)
    local s = cur and lista[cur]
    local ahora = s and s.ahoraTxt or L("al máximo", "maxed out")
    local _, hh = k:texto(tx, y + 44, L("AHORA: ", "NOW: ") .. ahora, { tam = 12, color = C().tenue, ancho = tw })
    yy = y + 44 + hh
  else
    k:texto(0, 0, "—", { tam = 12, color = C().tenue, punto = { "TOPRIGHT", k.marco, "TOPLEFT", LISTA_W - 12, -(y + 11) }, sinAnotar = true })
    local motivo = ""
    local util = false
    for _, x in ipairs(p.recomendadas or {}) do if x == id then util = true end end
    for _, x in ipairs(p.faltan or {}) do if x == id then util = true end end
    if util then motivo = L(" · útil para tu objetivo", " · useful for your goal")
    elseif id == 129 then motivo = L(" · te ahorra comida", " · saves you food") end
    local _, hh = k:texto(tx, y + 32, L("Sin aprender", "Not learned") .. motivo, { tam = 12, color = C().tenue, ancho = tw })
    yy = y + 32 + hh
  end
  if yy + 12 > y + h then h = yy + 12 - y; t:SetHeight(h); k:hasta(y + h) end
  k:zona(0, y, LISTA_W, h, function()
    WowFExportarDB = WowFExportarDB or {}
    WowFExportarDB.profVista = id
    redibujar(ctx)
  end, L("Clic: ver ", "Click: see ") .. nombre)
  return y + h
end

local function ayudaPaso(s, nombre)
  return function(tt)
    local ok = false
    if s.item and tt.SetItemByID then ok = pcall(tt.SetItemByID, tt, s.item) end
    if not ok then tt:SetText(WowF.T(s.a or s.b or nombre or ""), 1, 1, 1) end
    if s.tipo == "receta" then
      WowF.ayudaPasoReceta(tt, s)
    elseif s.tipo == "farm" then
      tt:AddLine(L("Recoge: ", "Gather: ") .. tostring(s.nodos or ""), 0.85, 0.82, 0.76, true)
      if s.zona then tt:AddLine(L("Mejor zona: ", "Best zone: ") .. s.zona, 0.85, 0.82, 0.76, true) end
      tt:AddLine(L("Clic: ruta de farmeo en el mapa", "Click: farming route on the map"), 0.49, 0.77, 0.35, true)
    elseif s.tipo == "rango" then
      tt:AddLine(WowF.T(s.b or ""), 0.85, 0.82, 0.76, true)
      if s.e then tt:AddLine(s.e[1] .. (s.e[7] and (" · " .. s.e[7]) or "") .. L(" · clic: alfiler", " · click: pin"), 0.49, 0.77, 0.35, true)
      elseif s.eSinPos and WowF.textoSinPosicion then tt:AddLine(WowF.textoSinPosicion(s.eSinPos[1]), 1, 0.54, 0.17, true) end
    else
      tt:AddLine(WowF.T(s.b or ""), 0.85, 0.82, 0.76, true)
    end
  end
end
local function clicPaso(s, nombre)
  if s.tipo == "farm" then farmeo(nombre)
  elseif s.tipo == "rango" then marcarEntrenador(s.e, nombre)
  elseif s.tipo == "receta" then WowF.irPasoReceta(s, nombre) end
end

-- Paso a paso: 4 tramos alrededor del que toca (el anterior hecho, el de AHORA y los dos siguientes)
local function tarjetaPasos(k, id, x, y, w, ctx)
  local K = WowF.vistaKit
  local lista, cur = pasosDe(id)
  local nombre = nombreProf(id)
  local t = k:tarjeta(x, y, w, 100)
  k:rotulo(x + 16, y + 12, L("Paso a paso", "Step by step"), C().oro)
  local cy = y + 38
  if #lista == 0 then
    local _, h = k:texto(x + 16, cy, SIN_DATOS(), { tam = 13, color = C().tenue, ancho = w - 32 })
    t:SetHeight(cy + h + 12 - y)
    return cy + h + 12
  end
  local ini = math.max(1, (cur or #lista) - 1)
  if ini + 3 > #lista then ini = math.max(1, #lista - 3) end
  local n = math.min(4, #lista - ini + 1)
  local gap = 10
  local cw = (w - 32 - gap * 3) / 4
  local tm = (E().tema and E().tema()) or {}
  local acento = tm.linea or C().brasa
  -- Medir primero el alto (la casilla mas alta, minimo 132)
  local alto = 132
  local celdas = {}
  for j = 0, n - 1 do
    local i = ini + j
    local s = lista[i]
    local cx = x + 16 + j * (cw + gap)
    local ahora = (i == cur)
    local fondo, borde, est, color = K.CASILLA, K.CASILLA_BORDE, nil, nil
    if s.hecho then fondo, borde, est, color = C().verdef, { 0.247, 0.42, 0.165 }, "ya", nil
    elseif ahora then fondo, borde, est, color = K.AHORA_FONDO, acento, "ahora", "verde" end
    local casilla = k:tarjeta(cx, cy, cw, alto, nil, fondo, borde, true)
    k:icono(cx + 12, cy + 12, 32, s.icono or iconoProf(id), color, not s.hecho and not ahora)
    k:bola(cx + cw - 32, cy + 10, s.hecho and CHECK or tostring(i), est)
    local titulo = s.a or (L("De ", "From ") .. ((ahora and s.desde and (habilidad(id) or 0) > s.desde) and (habilidad(id) or s.desde) or s.desde) .. L(" a ", " to ") .. s.hasta)
    local _, ha = k:texto(cx + 12, cy + 54, titulo, { tam = 14, peso = "negrita", color = C().texto, ancho = cw - 24 })
    local _, hb = k:texto(cx + 12, cy + 54 + ha + 3, s.b or "", { tam = 13, color = C().tenue, ancho = cw - 24 })
    local fin = cy + 54 + ha + 3 + hb
    if s.nota then
      local _, hn = k:texto(cx + 12, fin + 4, s.nota, { tam = 11, color = C().tenue, ancho = cw - 24 })
      fin = fin + 4 + hn
    end
    if ahora then
      k:chip(cx + 12, fin + 8, L("Ahora", "Now"), "brasa")
      fin = fin + 8 + 20
    end
    if fin + 12 - cy > alto then alto = fin + 12 - cy end
    table.insert(celdas, { casilla = casilla, cx = cx, s = s })
  end
  for _, c in ipairs(celdas) do
    c.casilla:SetHeight(alto)
    k:zona(c.cx, cy, cw, alto, function() clicPaso(c.s, nombre) end, ayudaPaso(c.s, nombre))
  end
  local fin = cy + alto + 16
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin
end

-- Las dos de abajo: Mejor sitio ahora | Lo que ganas
local function tarjetasDos(k, id, p, x, y, w)
  local nombre = nombreProf(id)
  local rango, maximo = habilidad(id)
  local cw = (w - 12) / 2
  -- Mejor sitio ahora
  local t1 = k:tarjeta(x, y, cw, 100)
  k:rotulo(x + 16, y + 14, L("Mejor sitio ahora", "Best spot now"))
  local okS, sitio = pcall(sitioAhora, id, rango)
  if not okS then sitio = nil end
  local y1
  if sitio then
    local _, hz = k:texto(x + 16, y + 36, sitio.zona or "", { tam = 17, letra = "marca", color = C().texto, ancho = cw - 32 })
    local _, hs = k:texto(x + 16, y + 36 + hz + 4, sitio.sub or "", { tam = 13, color = C().tenue, ancho = cw - 32 })
    y1 = y + 36 + hz + 4 + hs
    if sitio.fn then
      k:boton(x + 16, y1 + 14, (sitio.boton or L("Ruta de farmeo", "Farming route")) .. " ›", "estandarte", false, sitio.fn)
      y1 = y1 + 14 + 34
    end
  else
    local _, hs = k:texto(x + 16, y + 36, SIN_DATOS(), { tam = 13, color = C().tenue, ancho = cw - 32 })
    y1 = y + 36 + hs
  end
  -- Lo que ganas
  local x2 = x + cw + 12
  local t2 = k:tarjeta(x2, y, cw, 100)
  k:rotulo(x2 + 16, y + 14, L("Lo que ganas", "What you gain"), C().oro)
  local info = (p.objetivoInfo and p.objetivoInfo.t) or ""
  if id == 129 or id == 185 or id == 356 then
    info = L("No ocupa hueco: la tienes además de tus dos principales.", "It does not use a slot: you have it on top of your two main ones.")
      .. (id == 129 and L(" Te cura sin gastar comida ni pociones.", " It heals you without spending food or potions.") or "")
  end
  if info == "" then info = SIN_DATOS() end
  local _, hi = k:texto(x2 + 16, y + 36, info, { tam = 13, color = WowF.vistaKit.CLARO, ancho = cw - 32 })
  local y2 = y + 36 + hi + 12
  k:raya(x2 + 16, y2, cw - 32)
  y2 = y2 + 12
  -- Entrenador del rango que te toca (el siguiente al que ya tienes)
  local tope
  for _, cap in ipairs((WowFDatos and WowFDatos.caps) or {}) do if not maximo or cap[2] > maximo then tope = cap[2]; break end end
  local caps = (WowFDatos and WowFDatos.caps) or {}
  tope = tope or (caps[#caps] and caps[#caps][2]) or 75
  local e, eSinPos = entrenadorPara(id, tope)
  k:retrato(x2 + 16, y2, 40, { nombre = (e or eSinPos or {})[1], icono = ICONO_ENTRENADOR })
  k:texto(x2 + 66, y2 + 2, L("Entrenador de ", "") .. nombre .. L("", " trainer"), { tam = 14, peso = "negrita", color = C().texto })
  if e then
    -- 12-oct: el lugar con ancho fijo y el boton DEBAJO (pegado al texto se salia de la tarjeta)
    local lugar = e[1] .. (e[7] and (", " .. e[7]) or "")
    local _, hl = k:texto(x2 + 66, y2 + 22, lugar, { tam = 12, color = C().tenue, ancho = cw - 82 })
    k:boton(x2 + 66, y2 + 22 + hl + 4, L("Marcar en el mapa", "Mark on the map"), "terciario", false, function() marcarEntrenador(e, nombre) end)
    y2 = y2 + hl + 22
  elseif eSinPos then
    k:texto(x2 + 66, y2 + 22, (WowF.textoSinPosicion and WowF.textoSinPosicion(eSinPos[1])) or SIN_DATOS(), { tam = 12, color = C().tenue, ancho = cw - 82 })
  else
    k:texto(x2 + 66, y2 + 22, SIN_DATOS(), { tam = 12, color = C().tenue, ancho = cw - 82 })
  end
  y2 = y2 + 40
  local fin = math.max(y1, y2) + 16
  t1:SetHeight(fin - y); t2:SetHeight(fin - y)
  k:hasta(fin)
  return fin
end

-- Ficha de la profesion elegida (derecha)
local function ficha(k, id, p, x, y, w, ctx)
  local nombre = nombreProf(id)
  local rango, maximo = habilidad(id)
  local secundaria = (id == 129 or id == 185 or id == 356)
  local t = k:tarjeta(x, y, w, 84, "principal")
  k:icono(x + 16, y + 16, 52, iconoProf(id), nil, not rango)
  k:rotulo(x + 82, y + 14, secundaria and L("Profesión secundaria", "Secondary profession") or L("Profesión principal", "Primary profession"))
  local _, hn = k:texto(x + 82, y + 32, nombre, { tam = 20, letra = "marca", color = C().texto })
  local objetivo = (WowF.OBJETIVOS and WowF.OBJETIVOS[p.objetivo]) or ""
  objetivo = ((WowF.T and WowF.T(objetivo)) or objetivo):lower()
  local sub
  if rango then
    local rg = RANGO[maximo or 0] or ""
    sub = (rg ~= "" and (L("Rango ", "Rank ") .. rg .. " · ") or "") .. rango .. L(" de ", " of ") .. (maximo or "?") .. (objetivo ~= "" and (L(" · objetivo: ", " · goal: ") .. objetivo) or "")
  else
    sub = L("Aún no la tienes: el paso 1 es tu entrenador", "You do not have it yet: step 1 is your trainer") .. (objetivo ~= "" and (L(" · objetivo: ", " · goal: ") .. objetivo) or "")
  end
  local _, hs = k:texto(x + 82, y + 32 + hn + 2, sub, { tam = 13, color = C().tenue, ancho = w - 82 - 200 })
  local fin = math.max(y + 84, y + 32 + hn + 2 + hs + 14)
  if rango and maximo then
    local _, w2 = k:cifra(x + w - 16, y + 18, math.max(0, maximo - rango), L("te faltan", "to go"), true)
    k:cifra(x + w - 16 - w2 - 24, y + 18, rango, L("de ", "of ") .. maximo, true)
  end
  t:SetHeight(fin - y)
  k:hasta(fin)
  local y2 = tarjetaPasos(k, id, x, fin + 12, w, ctx)
  return tarjetasDos(k, id, p, x, y2 + 12, w)
end


-- ===================== Secciones de otros archivos en tarjetas =====================
-- WowF.seccionObjetivoProf / seccionSecundaria / seccionPesca / seccionFavor / seccionCampamento / seccionLegacy reciben el
-- mismo "h" que les pasa el Libro (item, cab, nota, separador...). Aqui ese h dibuja tarjetas: cada cab abre una tarjeta
-- con su titulo, los item son filas con icono, las notas texto tenue. Nada se pierde: es la misma informacion.
local RECOLOR = {} -- color del juego -> clave del tema (asignado aparte: no es un diccionario es->en)
for _, par in ipairs({ { "ffd100", "oro" }, { "33ff66", "verde" }, { "999999", "tenue" }, { "ffffff", "texto" }, { "ff9933", "brasa" }, { "66ccff", "orocl" } }) do RECOLOR[par[1]] = par[2] end
local function recolor(s)
  if type(s) ~= "string" then return s end
  local cod = (E() and E().cod) or {}
  return (s:gsub("|c[fF][fF](%x%x%x%x%x%x)", function(hex)
    local n = RECOLOR[hex:lower()]
    return (n and cod[n]) or ("|cff" .. hex)
  end))
end
local function limpio(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local function colorCalidad(q)
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex then return ITEM_QUALITY_COLORS[q].hex end
  return CALIDAD[q] or "|cffffffff"
end
local function hObj(id)
  local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  if o then return o[1], o[2], o[3], o[4] end
  return "objeto " .. tostring(id), 1, "", nil
end
local function hIcono(ic, id) return iconoObj(ic, id) or "Interface\\Icons\\INV_Misc_QuestionMark" end
local function nivelActual() return (UnitLevel and UnitLevel("player")) or 1 end
local function flecha() return WowF.vistaKit.acentoCod() .. "›|r" end

local function flujo(k, x, y, w)
  local F = { y = y }
  local t, ty, cy, ultimo
  function F.cerrar()
    if not t then return end
    local fin = cy + 6
    t:SetHeight(fin - ty)
    k:hasta(fin)
    F.y = fin + 12
    t = nil
  end
  function F.abrir(titulo, accion)
    F.cerrar()
    ty = F.y
    t = k:tarjeta(x, ty, w, 40)
    cy = ty + 14
    ultimo = nil
    if titulo and titulo ~= "" then
      local tw = w - 32 - (accion and 24 or 0)
      local _, h = k:texto(x + 16, cy, limpio(titulo), { tam = 16, letra = "marca", color = C().texto, ancho = tw })
      if accion then
        k:texto(x + w - 28, cy, flecha(), { tam = 16, sinAnotar = true })
        k:zona(x, cy - 4, w, h + 8, accion)
      end
      cy = cy + h + 10
    end
  end
  local function asegurar() if not t then F.abrir(nil) end end
  function F.cab(texto, accion) F.abrir(texto, accion) end
  function F.nota(texto, accion)
    asegurar()
    local tw = w - 32 - (accion and 24 or 0)
    local _, h = k:texto(x + 16, cy, recolor(texto), { tam = 13, color = C().tenue, ancho = tw })
    if accion then
      k:texto(x + w - 28, cy, flecha(), { tam = 16, sinAnotar = true })
      k:zona(x + 8, cy - 3, w - 16, h + 6, accion, L("Clic", "Click"))
    end
    cy = cy + h + 8
    ultimo = "nota"
  end
  function F.item(o)
    asegurar()
    o = o or {}
    if ultimo == "item" and o.icono then k:raya(x + 16, cy - 4, w - 32); cy = cy + 4 end
    local sx = x + 16 + math.min(tonumber(o.sangria) or 0, 24)
    local tamI = o.chico and 28 or 36
    local tx = sx
    if o.icono then k:icono(sx, cy, tamI, o.icono); tx = sx + tamI + 10 end
    local tw = x + w - 16 - tx - (o.accion and 24 or 0)
    local _, h1 = k:texto(tx, cy, recolor(o.texto or ""), { tam = o.chico and 13 or 14, peso = "medio", color = C().texto, ancho = tw })
    local alto = h1
    if o.sub and o.sub ~= "" then
      local _, h2 = k:texto(tx, cy + h1 + 2, recolor(o.sub), { tam = 12, color = C().tenue, ancho = tw })
      alto = h1 + 2 + h2
    end
    if o.icono and tamI > alto then alto = tamI end
    if o.accion then k:texto(x + w - 28, cy + math.max(0, (alto - 16) / 2), flecha(), { tam = 16, sinAnotar = true }) end
    if o.accion or o.objeto or o.ayuda then
      local ayuda = o.ayuda
      if o.objeto then
        local id = o.objeto
        ayuda = function(tt)
          local ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, id)
          if not ok then tt:SetText(limpio(o.texto), 1, 1, 1) end
        end
      end
      k:zona(x + 8, cy - 3, w - 16, alto + 6, o.accion, ayuda)
    end
    cy = cy + alto + 10
    ultimo = "item"
  end
  function F.separador() F.cerrar() end
  -- La misma lista de piezas fabricadas que pinta el Libro (veredicto, materiales en bolsas)
  local VERDE, GRIS, ORO = "|cff33ff66", "|cff999999", "|cffffd100"
  local VEREDICTO = { si = VERDE .. L("VALE LA PENA", "WORTH IT") .. "|r", opcional = GRIS .. L("opcional", "optional") .. "|r", ya = GRIS .. L("no hace falta", "not needed") .. "|r", normal = ORO .. L("útil", "useful") .. "|r" }
  function F.fabricadas(lista)
    for _, e in ipairs(lista or {}) do
      local tz = trozos(e[3])
      local nombre, ranura = (tz[1] or ""):match("^(.-) %((.-)%)$")
      local prof = (tz[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aun no disponible en WoW Forever; se actualizara)", "(level not yet available in WoW Forever; will be updated)"))
      local ya = e.i and tengo(e.i) > 0
      local mats = {}
      for _, m in ipairs(e.m or {}) do
        local tn = tengo(m[1])
        table.insert(mats, m[2] .. " " .. (m[3] or "?") .. (tn >= m[2] and (VERDE .. " (ok)|r" .. GRIS) or (tn > 0 and (L(" (tienes ", " (you have ") .. tn .. ")") or "")))
      end
      local v, porque = "normal", ""
      if WowF.valeLaPena then v, porque = WowF.valeLaPena(e) end
      local apagada = (v == "opcional" or v == "ya")
      F.item({ texto = GRIS .. L("Nv ", "Lv ") .. e[1] .. "  |r" .. (VEREDICTO[v] or "") .. "  " .. (ya and (VERDE .. L("[en tus bolsas] ", "[in your bags] ") .. "|r") or "") .. (apagada and GRIS or colorCalidad(e.q or 1)) .. (nombre or tz[1] or "?") .. "|r" .. GRIS .. "  " .. (ranura or "") .. "|r",
        sub = (v == "si" and VERDE or GRIS) .. (porque or "") .. "|r\n" .. GRIS .. prof .. (#mats > 0 and ("  ·  " .. table.concat(mats, ", ")) or "") .. "|r", icono = hIcono(e.ic, e.i), objeto = e.i })
    end
  end
  -- Gancho para secciones que dibujan con el kit (WowF.seccionCajas): cierra la tarjeta abierta y les da la posicion actual
  function F.tarjetas(fn)
    F.cerrar()
    local ny = fn(k, x, F.y, w)
    if type(ny) == "number" then k:hasta(ny); F.y = ny + 12 end
  end
  F.h = { tarjetas = F.tarjetas, item = F.item, cab = F.cab, nota = F.nota, fabricadas = F.fabricadas, obj = hObj, icono = hIcono, tengo = tengo,
    colorCalidad = colorCalidad, nivelActual = nivelActual, separador = F.separador, entrenadorPara = entrenadorPara, marcarEntrenador = marcarEntrenador }
  -- Corre una seccion externa sin romper la vista si falla
  function F.correr(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then F.nota(GRIS .. SIN_DATOS() .. "|r"); WowF.libroErrorVista = "Profesiones: " .. tostring(err) end
  end
  return F
end

-- ===================== Sin objetivo: tres tarjetas grandes para elegir =====================
local OBJ_ICONO = { fabricar = "Interface\\Icons\\Trade_BlackSmithing", oro = "Interface\\Icons\\INV_Misc_Coin_02", pvp = "Interface\\Icons\\INV_Sword_27" }
local function objAyuda(o)
  if o == "fabricar" then return L("Las que te hacen tu propia armadura y armas mientras subes.", "The ones that make your own armor and weapons while you level up.") end
  if o == "oro" then return L("Las que más se venden en la casa de subastas.", "The ones that sell best at the auction house.") end
  if o == "pvp" then return L("Las que dan ventaja contra otros jugadores.", "The ones that give you an edge against other players.") end
  return ""
end
local function vistaElegir(k, p, ancho, ctx)
  local cod = E().cod or {}
  local _, h = k:texto(0, 0, L("Paso 1: elige qué quieres con tus profesiones", "Step 1: choose what you want from your professions"), { tam = 20, letra = "marca", color = C().texto })
  local _, wc = k:texto(0, h + 6, L("Según lo que elijas te decimos qué profesiones aprender, dónde están los entrenadores y el paso a paso.",
    "Depending on what you choose, we tell you which professions to learn, where the trainers are and the step by step."), { tam = 13, color = C().tenue, ancho = ancho - 140 })
  k:chip(ancho, 4, L("Obligatorio", "Required"), "brasa", true)
  local y = h + 6 + wc + 16
  local lista = WowF.ORDEN_OBJETIVOS or { "fabricar", "oro", "pvp" }
  local n = #lista
  local gap = 12
  local cw = (ancho - gap * (n - 1)) / n
  local tarjetas, alto = {}, 220
  for i, o in ipairs(lista) do
    local x = (i - 1) * (cw + gap)
    local t = k:tarjeta(x, y, cw, alto, i == 1 and "recomendada" or nil)
    k:icono(x + 20, y + 20, 56, OBJ_ICONO[o] or ICONO_PROF, i == 1 and "oro" or nil)
    local titulo = (WowF.OBJETIVOS and WowF.OBJETIVOS[o]) or o
    titulo = (WowF.T and WowF.T(titulo)) or titulo
    local _, ht = k:texto(x + 20, y + 90, titulo, { tam = 18, letra = "marca", color = C().texto, ancho = cw - 40 })
    k:rotulo(x + 20, y + 90 + ht + 10, L("Por qué", "Why"), C().oro)
    local _, ha = k:texto(x + 20, y + 90 + ht + 28, objAyuda(o), { tam = 13, color = WowF.vistaKit.CLARO, ancho = cw - 40 })
    local fin = y + 90 + ht + 28 + ha
    table.insert(tarjetas, { t = t, x = x, o = o, fin = fin })
    if fin + 66 - y > alto then alto = fin + 66 - y end
  end
  for _, c in ipairs(tarjetas) do
    c.t:SetHeight(alto)
    k:boton(c.x + 20, y + alto - 50, L("Elegir", "Choose") .. " ›", "estandarte", false, function()
      if WowF.elegirObjetivo then WowF.elegirObjetivo(c.o) end
      redibujar(ctx)
    end, { ancho = cw - 40 })
  end
  y = y + alto + 12
  local t = k:tarjeta(0, y, ancho, 40, "hundida")
  local _, hn = k:texto(16, y + 14, (cod.brasa or "") .. L("Elige una de las tres opciones de arriba. Después aquí abajo te sale todo: qué profesiones aprender, dónde están los entrenadores y el paso a paso.",
    "Choose one of the three options above. Then everything shows up here: which professions to learn, where the trainers are and the step by step.") .. "|r", { tam = 13, ancho = ancho - 32 })
  t:SetHeight(hn + 28)
  k:hasta(y + hn + 28)
  return y + hn + 28
end

-- ===================== Mis profesiones: lo que te conviene (el "Para ti lo mejor" del Libro) =====================
local function nombresProf(ids)
  local n = {}
  for _, id in ipairs(ids or {}) do table.insert(n, nombreProf(id)) end
  return table.concat(n, " + ")
end
local function tarjetaConviene(k, p, y, ancho)
  local info = p.objetivoInfo or {}
  local mejor = nombresProf(p.recomendadas)
  local tieneOtras = info.otras and #info.otras > 0
  if mejor == "" and (info.por or "") == "" and not tieneOtras then return y end
  local cod = E().cod or {}
  local t = k:tarjeta(0, y, ancho, 60, "recomendada")
  local cy = y + 14
  local col1 = tieneOtras and math.floor((ancho - 32) * 0.55) or (ancho - 32)
  k:rotulo(16, cy, L("Lo que te conviene", "What suits you"), C().oro)
  cy = cy + 22
  if mejor ~= "" then
    local claseN = (UnitClass and UnitClass("player")) or L("tu clase", "your class")
    k:icono(16, cy, 40, iconoProf((p.recomendadas or {})[1]), "oro")
    local _, hm = k:texto(66, cy, L("Para ti (" .. claseN .. ") lo mejor: ", "Best for you (" .. claseN .. "): ") .. (cod.verde or "") .. mejor .. "|r", { tam = 15, peso = "negrita", color = C().texto, ancho = col1 - 50 })
    cy = cy + math.max(40, hm) + 8
    -- 13-oct (Andy): desde aqui mismo, un boton por profesion recomendada al entrenador mas cercano de tu faccion
    -- 13-oct (Andy): uno debajo del otro, con el ancho de la columna; lado a lado se salian de la tarjeta
    local bAncho = math.min(col1, 340)
    for _, id in ipairs(p.recomendadas or {}) do
      local nom = nombreProf(id)
      local e, eSinPos = entrenadorPara(id, 75)
      local dest = e or eSinPos
      local ayuda = dest and ((dest[1] or "") .. ((dest[7] and dest[7] ~= "") and (", " .. dest[7]) or "") .. "\n" .. L("Clic: te lo marco en el mapa (el más cercano de tu facción).", "Click: I mark it on the map (the closest of your faction).")) or SIN_DATOS()
      k:boton(16, cy, L("Ir al entrenador de ", "Go to the ") .. nom .. L("", " trainer") .. " ›", "secundario", false, function()
        if not dest then print(SIN_DATOS()); return end
        if WowF.verEntrenador then WowF.verEntrenador(dest, nom) else marcarEntrenador(dest, nom) end
      end, { ayuda = ayuda, ancho = bAncho })
      cy = cy + 40
    end
    if #(p.recomendadas or {}) > 0 then cy = cy + 4 end
  end
  if (info.por or "") ~= "" then
    local _, hp = k:texto(16, cy, (cod.oro or "") .. L("Por qué: ", "Why: ") .. "|r" .. info.por, { tam = 13, color = WowF.vistaKit.CLARO, ancho = col1 })
    cy = cy + hp + 8
  end
  local tg = p.tengo or {}
  if #tg > 0 and mejor ~= "" then
    local iguales = true
    for _, id in ipairs(p.recomendadas or {}) do
      local esta = false
      for _, x in ipairs(tg) do if x == id then esta = true end end
      if not esta then iguales = false end
    end
    if iguales then
      k:chip(16, cy, L("Ya tienes las dos correctas para esto", "You already have the right two for this"), "verde")
      cy = cy + 28
    else
      local _, hc = k:texto(16, cy, (cod.brasa or "") .. L("Tú tienes " .. nombresProf(tg) .. ". Para esto te conviene " .. mejor .. ".", "You have " .. nombresProf(tg) .. ". For this you should get " .. mejor .. ".") .. "|r"
        .. (cod.tenue or "") .. L(" Arriba sigue el paso a paso de las que tienes.", " The step by step of the ones you have is above.") .. "|r", { tam = 13, ancho = col1 })
      cy = cy + hc + 8
    end
  end
  -- Otras opciones (columna derecha)
  local cy2 = y + 14
  if tieneOtras then
    local x2 = 16 + col1 + 24
    local w2 = ancho - x2 - 16
    k:rotulo(x2, cy2, L("Otras opciones", "Other options"), C().tenue)
    cy2 = cy2 + 22
    for i, o in ipairs(info.otras) do
      if i > 1 then k:raya(x2, cy2 - 5, w2); cy2 = cy2 + 4 end
      local _, h1 = k:texto(x2, cy2, (o[1] or "") .. (((o[2] or "") ~= "") and ((cod.tenue or "") .. "  (" .. o[2] .. ")|r") or ""), { tam = 14, peso = "negrita", color = C().texto, ancho = w2 })
      local _, h2 = k:texto(x2, cy2 + h1 + 2, o[3] or "", { tam = 12, color = C().tenue, ancho = w2 })
      cy2 = cy2 + h1 + 2 + h2 + 10
    end
  end
  local fin = math.max(cy, cy2) + 8
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin
end

-- ===================== Secundarias (11-oct: por tarjetas, como "Mis profesiones") =====================
-- Las recetas, rutas y notas salen de WowF.seccionSecundaria / WowF.seccionPesca (wowF_ProfObjetivo.lua), las MISMAS que
-- arma el Libro: aqui se recogen sus llamadas (item / cab / nota, con su clic y su tooltip) y se dibujan como tarjetas.
-- Cada receta se cruza por id con WowF.recetasSecundaria para mostrar rango, efecto, materiales y de donde sale la receta.
-- Todo va en la tabla SEC (tope de 200 locales del archivo).
local SEC = {}
function SEC.Y(s) if WowF.yaTraducido then return WowF.yaTraducido(s) end return s end
function SEC.cod(n, def) local c = (E() and E().cod) or {}; return c[n] or def end
function SEC.lineas(s)
  local t = {}
  if type(s) ~= "string" or s == "" then return t end
  for l in (s .. "\n"):gmatch("(.-)\n") do if l ~= "" then table.insert(t, l) end end
  return t
end
-- Lo que hace el objeto, con los numeros reales de Forever (copia de efectoSec de wowF_ProfObjetivo.lua, que es local)
function SEC.efecto(e)
  local t = {}
  if e.tipo == "v" and (e.cura or 0) > 0 then table.insert(t, L("venda: cura " .. e.cura .. " de salud", "bandage: heals " .. e.cura .. " health")) end
  if e.tipo == "a" then table.insert(t, L("quita veneno", "removes poison")) end
  if e.tipo ~= "v" and (e.cura or 0) > 0 then table.insert(t, L("recupera " .. e.cura .. " de salud", "restores " .. e.cura .. " health")) end
  if (e.bufo or 0) > 0 and (e.stat or "") ~= "" then table.insert(t, "+" .. e.bufo .. " " .. e.stat) end
  if (e.xp or 0) > 0 then table.insert(t, L("+" .. e.xp .. "% de XP al matar", "+" .. e.xp .. "% XP from kills")) end
  if (e.mana or 0) > 0 then table.insert(t, L("recupera " .. e.mana .. " de mana", "restores " .. e.mana .. " mana")) end
  return table.concat(t, ", ")
end
-- De donde sale la receta (mismo criterio que textoFuente de wowF_ProfObjetivo.lua); "La sabes" solo si el juego lo confirma
function SEC.fuente(e, R)
  if e.spell and IsPlayerSpell then
    local ok, r = pcall(IsPlayerSpell, e.spell)
    if ok and r == true then return L("Ya la conoces", "You know it"), "verde" end
  end
  if e.fuente == "A" then
    if R then return L("Ya la conoces", "You know it"), "verde" end
    return L("Viene con la profesión", "Comes with the profession"), "gris"
  end
  if e.fuente == "B" then return L("Botín o subasta", "Loot or auction house"), "gris" end
  if e.fuente == "V" then return L("Vendedor", "Vendor"), "oro" end
  if e.fuente == "F" then return "Merchant's Favor", "oro" end
  return L("Entrenador", "Trainer"), "oro"
end
-- Corre la seccion con un "h" que solo apunta lo que pide dibujar
function SEC.capturar(fn, ...)
  local lista = {}
  local function apuntar(tipo, o) table.insert(lista, { tipo = tipo, o = o or {} }) end
  local h = { item = function(o) apuntar("item", o) end, cab = function(t, a) apuntar("cab", { texto = t, accion = a }) end,
    nota = function(t, a) apuntar("nota", { texto = t, accion = a }) end, separador = function() end,
    fabricadas = function(l) apuntar("fab", { lista = l }) end, obj = hObj, icono = hIcono, tengo = tengo, colorCalidad = colorCalidad,
    nivelActual = nivelActual, entrenadorPara = entrenadorPara, marcarEntrenador = marcarEntrenador }
  local args = { ... }
  table.insert(args, h)
  local ok, err = pcall(fn, unpack(args))
  return ok, lista, err
end
-- Icono de una ruta: la hierba o el material de farmeo que nombra
function SEC.iconoRuta(prof, o)
  local txt = limpio(o.texto)
  local ids = {}
  if WowF.hierbaSecundaria then local ok, id = pcall(WowF.hierbaSecundaria, prof); if ok and id then table.insert(ids, id) end end
  if WowF.materialSecundaria then local ok, id = pcall(WowF.materialSecundaria, prof); if ok and id then table.insert(ids, id) end end
  for _, id in ipairs(ids) do
    local n, _, ic = hObj(id)
    if n and txt:find(n, 1, true) then return hIcono(ic, id) end
  end
  return "Interface\\Icons\\INV_Misc_Map_01"
end
-- Tooltip de una fila con objeto: el del juego y, debajo, las lineas de la guia
function SEC.ayudaObjeto(o)
  return function(tt)
    local ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, o.objeto)
    if not ok then tt:SetText(limpio(o.texto), 1, 1, 1) end
    if tt.AddLine then for _, l in ipairs(SEC.lineas(o.sub)) do pcall(tt.AddLine, tt, limpio(l), 0.8, 0.8, 0.8, true) end end
  end
end
-- Una receta (o un objeto suelto, como los peces) dentro de la tarjeta abierta
function SEC.fila(k, G, o, e, ancho)
  local tenue, verde, brasa = SEC.cod("tenue", "|cff999999"), SEC.cod("verde", "|cff33ff66"), SEC.cod("brasa", "|cffff9933")
  local cy = G.cy
  if G.ultimo == "fila" then k:raya(16, cy - 5, ancho - 32); cy = cy + 6 end
  local prox = G.seccion == "prox"
  local bw = o.accion and 120 or 0
  local tx = 16 + 36 + 12
  local tw = ancho - 16 - tx - bw
  k:icono(16, cy, 36, o.icono or hIcono(nil, o.objeto), e and (prox and "gris" or "verde") or nil)
  local nombre
  if e then
    local n, q = hObj(e.id)
    nombre = (((e.cant or 1) > 1) and (SEC.cod("oro", "|cffffd100") .. e.cant .. " x|r ") or "") .. colorCalidad(q or 1) .. n .. "|r"
  else
    nombre = recolor(o.texto or "")
  end
  local _, h1 = k:texto(tx, cy, SEC.Y(nombre), { tam = 14, peso = "negrita", color = C().texto, ancho = tw })
  local yy = cy + (tonumber(h1) or 16) + 4
  local resto = SEC.lineas(o.sub)
  if e then
    -- Chips: rango (verde si ya lo tienes), efecto, nivel de uso y de donde sale la receta
    local R = G.rango
    local cx, lim = tx, tx + tw
    local function chip(txt, color)
      local aprox = #txt * 6.5 + 18
      if cx > tx and cx + aprox > lim then cx = tx; yy = yy + 24 end
      local _, w = k:chip(cx, yy, txt, color)
      cx = cx + (tonumber(w) or aprox) + 6
    end
    chip(L("Rango ", "Skill ") .. e.nivel, (R and R >= e.nivel) and "verde" or "gris")
    local ef = SEC.efecto(e)
    if ef ~= "" then chip(ef, "neutro") end
    if (e.rl or 0) > nivelActual() then chip(L("Se usa desde el nivel ", "Usable from level ") .. e.rl, "brasa") end
    local ft, fc = SEC.fuente(e, R)
    chip(ft, fc)
    yy = yy + 26
    -- Materiales con lo que tienes en las bolsas
    if e.mats and #e.mats > 0 then
      local partes, todo = {}, true
      for _, m in ipairs(e.mats) do
        local n = hObj(m[1])
        local pide, tn = tonumber(m[2]) or 1, tengo(m[1])
        if tn >= pide then
          table.insert(partes, verde .. pide .. " " .. n .. "|r" .. tenue .. " · " .. L("tienes ", "you have ") .. tn .. "|r")
        else
          todo = false
          table.insert(partes, SEC.cod("texto", "|cffffffff") .. pide .. " " .. n .. "|r" .. tenue .. " · " .. L("tienes ", "you have ") .. tn .. "|r " .. brasa .. L("faltan ", "missing ") .. (pide - tn) .. "|r")
        end
      end
      local txt = tenue .. L("Materiales: ", "Materials: ") .. "|r" .. table.concat(partes, tenue .. ",  |r") .. (todo and (verde .. L("  ya lo tienes todo", "  you have it all") .. "|r") or "")
      local _, hm = k:texto(tx, yy, SEC.Y(txt), { tam = 12, color = C().texto, ancho = tw })
      yy = yy + (tonumber(hm) or 14) + 4
    end
    -- Lo demas del texto de siempre (si sube la habilidad, hierba, donde se pesca...). Fuera: el efecto, los materiales y
    -- la fuente, que ya van arriba (la fuente se queda si nombra al vendedor)
    local quitar = {}
    if ef ~= "" then quitar[1] = true end
    if #resto > 0 and e.fuente ~= "V" and e.fuente ~= "F" then quitar[#resto] = true end
    local necesitas = limpio(L("Necesitas: ", "You need: "))
    local otras = {}
    for i, l in ipairs(resto) do
      if not quitar[i] and limpio(l):sub(1, #necesitas) ~= necesitas then table.insert(otras, l) end
    end
    resto = otras
  end
  if #resto > 0 then
    local _, hs = k:texto(tx, yy, SEC.Y(recolor(table.concat(resto, "\n"))), { tam = 12, color = C().tenue, ancho = tw })
    yy = yy + (tonumber(hs) or 14) + 2
  end
  if o.accion then
    k:boton(ancho - 16, cy + 2, (e and e.fuente == "F") and L("Ir", "Go") or L("Alfiler", "Map pin"), "secundario", true, o.accion, { derecha = true })
  end
  local alto = math.max(36, yy - cy)
  if o.accion or o.objeto then
    k:zona(8, cy - 3, ancho - 16 - bw, alto + 6, o.accion, o.objeto and SEC.ayudaObjeto(o) or nil)
  end
  G.cy = cy + alto + 10
  G.ultimo = "fila"
end
-- Ruta de farmeo / de hierbas: tarjeta propia con icono, sitio y boton
function SEC.ruta(k, o, y, ancho, prof)
  local t = k:tarjeta(0, y, ancho, 60)
  local bw = o.accion and 180 or 0
  k:icono(16, y + 14, 40, SEC.iconoRuta(prof, o), o.accion and "verde" or "gris")
  local tx = 16 + 40 + 12
  local tw = ancho - 16 - tx - bw
  local _, h1 = k:texto(tx, y + 14, SEC.Y(recolor(o.texto or "")), { tam = 15, peso = "negrita", color = C().texto, ancho = tw })
  local cy = y + 14 + (tonumber(h1) or 16) + 4
  if (o.sub or "") ~= "" then
    local _, h2 = k:texto(tx, cy, SEC.Y(recolor(o.sub)), { tam = 12, color = C().tenue, ancho = tw })
    cy = cy + (tonumber(h2) or 14) + 2
  end
  if o.accion then
    k:zona(8, y + 8, ancho - 16 - bw, cy - y - 8, o.accion, limpio(o.sub or o.texto))
    k:boton(ancho - 16, y + 18, L("Marcar en el mapa", "Mark on the map"), "secundario", true, o.accion, { derecha = true })
  end
  local fin = math.max(cy, y + 14 + 40) + 12
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin + 12
end
-- Dibuja lo apuntado: cada cabecera abre una tarjeta, las recetas son filas, las rutas van aparte
function SEC.seccion(k, y, ancho, prof, titulo, fn, ...)
  local ok, lista, err = SEC.capturar(fn, ...)
  if titulo then
    local _, ht = k:texto(4, y, titulo, { tam = 17, letra = "marca", color = C().texto, ancho = ancho - 8 })
    y = y + (tonumber(ht) or 18) + 10
  end
  local r
  if prof ~= 356 and WowF.recetasSecundaria then
    local okr, rr = pcall(WowF.recetasSecundaria, prof)
    if okr and type(rr) == "table" then r = rr end
  end
  local G = { y = y, rango = r and r.rango, idx = { ya = 0, prox = 0 } }
  local function cerrar()
    if not G.t then return end
    local fin = G.cy + 4
    G.t:SetHeight(fin - G.ty)
    k:hasta(fin)
    G.y = fin + 12
    G.t = nil
  end
  local function abrir(texto)
    cerrar()
    G.ty = G.y
    G.t = k:tarjeta(0, G.ty, ancho, 40)
    G.cy = G.ty + 14
    G.ultimo = nil
    if texto and texto ~= "" then
      local _, h = k:texto(16, G.cy, SEC.Y(recolor(texto)), { tam = 15, letra = "marca", color = C().texto, ancho = ancho - 32 })
      G.cy = G.cy + (tonumber(h) or 16) + 10
    end
  end
  local function nota(o)
    if not G.t then abrir(nil) end
    local tw = ancho - 32 - (o.accion and 24 or 0)
    local _, h = k:texto(16, G.cy, SEC.Y(recolor(o.texto or "")), { tam = 13, color = C().tenue, ancho = tw })
    h = tonumber(h) or 14
    if o.accion then
      k:texto(ancho - 28, G.cy, flecha(), { tam = 16, sinAnotar = true })
      k:zona(8, G.cy - 3, ancho - 16, h + 6, o.accion, L("Clic", "Click"))
    end
    G.cy = G.cy + h + 8
    G.ultimo = "nota"
  end
  if not ok then
    WowF.libroErrorVista = "Profesiones: " .. tostring(err)
    lista = { { tipo = "nota", o = { texto = SIN_DATOS() } } }
  elseif #lista == 0 then
    lista = { { tipo = "nota", o = { texto = SIN_DATOS() } } }
  end
  local siguiente = L("Proximas al subir", "Next as you level up")
  local yaPuedes = L("Ya puedes", "You can now")
  for _, pz in ipairs(lista) do
    local o = pz.o
    if pz.tipo == "nota" then
      nota(o)
    elseif pz.tipo == "cab" then
      abrir(o.texto)
      G.seccion = nil
    elseif pz.tipo == "fab" then
      -- Ninguna seccion secundaria lo usa hoy; si llega, no se pierde: el flujo de siempre lo dibuja
      cerrar()
      local F = flujo(k, 0, G.y, ancho)
      F.fabricadas(o.lista)
      F.cerrar()
      G.y = F.y
    elseif o.objeto then
      if not G.t then abrir(nil) end
      local e
      local cual = G.seccion and r and r[G.seccion]
      if cual then
        G.idx[G.seccion] = G.idx[G.seccion] + 1
        e = cual[G.idx[G.seccion]]
        if not e or e.id ~= o.objeto then
          e = nil
          for _, x in ipairs(cual) do if x.id == o.objeto then e = x; break end end
        end
      end
      SEC.fila(k, G, o, e, ancho)
    elseif o.accion or (o.sub or "") ~= "" then
      cerrar()
      G.y = SEC.ruta(k, o, G.y, ancho, prof)
    else
      -- Cabecera ("Ya puedes", "Proximas al subir", "Donde pescar"...)
      abrir(o.texto)
      local tl = limpio(o.texto)
      if tl:find(siguiente, 1, true) then G.seccion = "prox"
      elseif tl:find(yaPuedes, 1, true) then G.seccion = "ya"
      else G.seccion = nil end
    end
  end
  cerrar()
  return G.y
end

local function vistaSecundarias(k, p, y, ancho, ctx)
  local t = k:tarjeta(0, y, ancho, 60)
  k:rotulo(16, y + 14, L("Profesiones secundarias", "Secondary professions"))
  local _, hn = k:texto(16, y + 36, L("First Aid, Cooking y Fishing no ocupan hueco: puedes tener las tres además de tus dos principales. Topes: 75, 150, 225 y 300; el nivel de personaje que pide cada uno aún no está disponible en Forever; se actualizará.",
    "First Aid, Cooking and Fishing do not use a slot: you can have all three plus your two main ones. Caps: 75, 150, 225 and 300; the character level each one requires is not available yet in Forever; will be updated."), { tam = 13, color = WowF.vistaKit.CLARO, ancho = ancho - 32 })
  local fin = y + 36 + hn + 14
  t:SetHeight(fin - y); k:hasta(fin)
  y = fin + 12
  for _, id in ipairs({ 129, 185 }) do
    y = ficha(k, id, p, 0, y, ancho, ctx) + 12
    if WowF.seccionSecundaria then
      y = SEC.seccion(k, y, ancho, id, L("Lo que fabricas con ", "What you make with ") .. nombreProf(id), WowF.seccionSecundaria, id)
    end
  end
  if WowF.seccionPesca then y = SEC.seccion(k, y, ancho, 356, nil, WowF.seccionPesca) end
  return y
end

-- ===================== Mas: entrenadores donde estas + Merchant's Favor, campamento y Legacy =====================
local function vistaMas(k, p, y, ancho)
  local cod = E().cod or {}
  if WowF.entrenadoresEn and WowF.mapaActual then
    local okM, m, zona = pcall(WowF.mapaActual)
    if not okM then m, zona = nil, "" end
    local okA, aqui = pcall(WowF.entrenadoresEn, m)
    if not okA or type(aqui) ~= "table" then aqui = {} end
    local t = k:tarjeta(0, y, ancho, 60)
    k:rotulo(16, y + 14, L("Entrenadores donde estás", "Trainers where you are"))
    local _, hz = k:texto(16, y + 34, ((zona or "") ~= "" and zona) or L("Zona actual", "Current zone"), { tam = 18, letra = "marca", color = C().texto })
    local cy = y + 34 + hz + 12
    if #aqui == 0 then
      local _, hn = k:texto(16, cy, L("Aquí no hay entrenadores de profesiones. El paso 1 de cada profesión te marca el más cercano. En el mapa (M) de cada ciudad o pueblo salen todos con su icono.",
        "There are no profession trainers here. Step 1 of each profession marks the nearest one. On the map (M) of each city or town they all show with their icon."), { tam = 13, color = C().tenue, ancho = ancho - 32 })
      cy = cy + hn + 8
    else
      local gap = 12
      local cw = (ancho - 32 - gap) / 2
      local fila = 0
      local altoFila = 0
      for i, tr in ipairs(aqui) do
        local col = (i - 1) % 2
        local cx = 16 + col * (cw + gap)
        local e = tr.e or {}
        local hasta = (WowF.rangoEntrenador and e[6]) and WowF.rangoEntrenador(e[6]) or "?"
        local casilla = k:tarjeta(cx, cy, cw, 64, nil, WowF.vistaKit.CASILLA, WowF.vistaKit.CASILLA_BORDE, true)
        k:icono(cx + 12, cy + 12, 36, iconoProf(tr.prof))
        local tw = cw - 60 - 12
        local _, h1 = k:texto(cx + 58, cy + 10, (cod.oro or "") .. (tr.nombre or "") .. "|r" .. ": " .. (e[1] or "?"), { tam = 14, peso = "negrita", color = C().texto, ancho = tw })
        local aprox = (WowF.esAproximado and WowF.esAproximado(e) and WowF.textoAprox) and ("\n" .. WowF.textoAprox()) or ""
        local _, h2 = k:texto(cx + 58, cy + 10 + h1 + 2, (e[3] or "?") .. ", " .. (e[4] or "?") .. L(" · enseña hasta ", " · teaches up to ") .. hasta .. aprox, { tam = 12, color = C().tenue, ancho = tw })
        local hh = math.max(64, 10 + h1 + 2 + h2 + 10)
        casilla:SetHeight(hh)
        k:zona(cx, cy, cw, hh, function() local fn = WowF.verEntrenador or WowF.marcarEntrenador; if fn then fn(e, tr.nombre) end end, L("Clic: verlo en el mapa", "Click: see it on the map"))
        if hh > altoFila then altoFila = hh end
        if col == 1 or i == #aqui then cy = cy + altoFila + 8; altoFila = 0; fila = fila + 1 end
      end
      local _, hn = k:texto(16, cy + 2, L("Clic en uno: verlo en el mapa. En el mapa (M) cada entrenador es un punto con el icono de su profesión debajo; los tuyos en verde y el que elegiste en dorado.",
        "Click one: see it on the map. On the map (M) each trainer is a dot with its profession icon below; yours in green and the one you chose in gold."), { tam = 12, color = C().tenue, ancho = ancho - 32 })
      cy = cy + 2 + hn + 8
    end
    local fin = cy + 6
    t:SetHeight(fin - y); k:hasta(fin)
    y = fin + 12
  end
  return y
end

-- ===================== Cajas y favor (12-oct, Andy: "que la gente lo vea ahi mismo, no debajo de Mas") =====================
-- Merchant's Favor (con la guia de Waylaid Crates, que wowF_Cajas.lua engancha debajo) y los objetos de campamento
local function vistaCajas(k, p, y, ancho)
  -- 16-oct (Andy: "que tenga sus cajitas"): vista nativa por tarjetas (wowF_VistaGuias.lua); si falla, la vieja
  if WowF.vistaCajas then local ok, ny = pcall(WowF.vistaCajas, k, p, y, ancho); if ok and type(ny) == "number" then return ny end; if not ok then WowF.libroErrorVista = "Profesiones: " .. tostring(ny) end end
  local F = flujo(k, 0, y, ancho)
  if WowF.seccionFavor then F.correr(WowF.seccionFavor, p, F.h); F.cerrar() end
  return F.y
end
-- 16-oct (Andy): sub-pestanas propias para la guia de campamento (wowF_GuiaCampamento.lua + la lista de wowF_Campamento.lua) y la de reputacion (wowF_Reputacion.lua)
local function vistaCampamento(k, p, y, ancho)
  -- 16-oct (Andy: "que tenga sus cajitas"): vista nativa por tarjetas (wowF_VistaGuias.lua); si falla, la vieja
  if WowF.vistaCampamento then local ok, ny = pcall(WowF.vistaCampamento, k, p, y, ancho); if ok and type(ny) == "number" then return ny end; if not ok then WowF.libroErrorVista = "Profesiones: " .. tostring(ny) end end
  local F = flujo(k, 0, y, ancho)
  if WowF.seccionGuiaCampamento then F.correr(WowF.seccionGuiaCampamento, p, F.h); F.cerrar() end
  if WowF.seccionCampamento then F.correr(WowF.seccionCampamento, p, F.h); F.cerrar() end
  return F.y
end
local function vistaReputacion(k, p, y, ancho)
  -- 16-oct (Andy: "que tenga sus cajitas"): vista nativa por tarjetas (wowF_VistaGuias.lua); si falla, la vieja
  if WowF.vistaReputacion then local ok, ny = pcall(WowF.vistaReputacion, k, p, y, ancho); if ok and type(ny) == "number" then return ny end; if not ok then WowF.libroErrorVista = "Profesiones: " .. tostring(ny) end end
  local F = flujo(k, 0, y, ancho)
  if WowF.seccionReputacion then F.correr(WowF.seccionReputacion, p, F.h); F.cerrar() end
  return F.y
end

-- ===================== Para vender / Fabricarte equipo / Para PvP =====================
local function vistaObjetivo(k, p, y, ancho)
  local F = flujo(k, 0, y, ancho)
  if WowF.seccionObjetivoProf then
    F.correr(WowF.seccionObjetivoProf, p, F.h)
  elseif p.sugerida then
    F.cab(L("Para fabricarte equipo: ", "To craft your gear: ") .. p.sugerida.nombre)
    F.nota(L("Hoy tienes dos de recolección: ganas oro vendiendo lo que sacas. Si cambias una por " .. p.sugerida.nombre .. " (la recomendada para tu clase), te fabricas esto:",
      "Today you have two gathering professions: you earn gold selling what you gather. If you swap one for " .. p.sugerida.nombre .. " (the one recommended for your class), you craft this:"))
    local proximas = {}
    for _, e in ipairs(p.sugerida.piezas or {}) do if e[1] >= nivelActual() - 3 and #proximas < 8 then table.insert(proximas, e) end end
    F.fabricadas(proximas)
  else
    F.nota(SIN_DATOS())
  end
  F.cerrar()
  return F.y
end

function WowF.vistaProfesiones(p, hoja, ancho, ctx)
  if not (WowF.estilo and WowF.estilo.tarjeta and WowF.vistaKit) then return nil end
  p = p or {}
  ctx = ctx or {}
  if not (WowFDatos and WowFDatos.caps) then return nil end
  ancho = ancho or 890
  local K = WowF.vistaKit
  if not vista then
    local m, kit = K.marcoDe(nil, hoja, ancho)
    vista = { marco = m, kit = kit }
  end
  local m, k = vista.marco, vista.kit
  if m.GetParent and m:GetParent() ~= hoja and m.SetParent then m:SetParent(hoja) end
  m:SetWidth(ancho)
  k:empezar()
  if WowF.objetivoElegido and not WowF.objetivoElegido() then
    vistaElegir(k, p, ancho, ctx)
  else
    local sub = ctx.sub or "mias"
    if sub ~= "objetivo" and sub ~= "secundarias" and sub ~= "cajas" and sub ~= "campamento" and sub ~= "reputacion" and sub ~= "mas" and sub ~= "legacy" then sub = "mias" end
    local y = barra(k, p, ancho, ctx, sub) + 12
    if sub == "mias" then
      local ids = idsLista(p)
      local sel = elegida(ids)
      local yl = y
      for _, id in ipairs(ids) do yl = tarjetaLista(k, id, yl, id == sel, p, ctx) + 8 end
      local yf = y
      if sel then yf = ficha(k, sel, p, LISTA_W + 12, y, ancho - LISTA_W - 12, ctx) end
      tarjetaConviene(k, p, math.max(yl - 8, yf) + 12, ancho)
    elseif sub == "objetivo" then
      vistaObjetivo(k, p, y, ancho)
    elseif sub == "secundarias" then
      vistaSecundarias(k, p, y, ancho, ctx)
    elseif sub == "cajas" then
      vistaCajas(k, p, y, ancho)
    elseif sub == "campamento" then
      vistaCampamento(k, p, y, ancho)
    elseif sub == "reputacion" then
      vistaReputacion(k, p, y, ancho)
    elseif sub == "legacy" then
      -- 12-oct (Andy: "un espacio aparte solo para los Legacy Points"): perks con tu rango real y que cambia cada uno en el addon
      -- 16-oct: vista nativa por tarjetas (wowF_VistaGuias.lua); si falla o no existe, la vieja
      local okL, nyL = false, nil
      if WowF.vistaLegacy then
        okL, nyL = pcall(WowF.vistaLegacy, k, p, y, ancho)
        if not okL then WowF.libroErrorVista = "Profesiones: " .. tostring(nyL) end
      end
      if not (okL and type(nyL) == "number") then
        local F = flujo(k, 0, y, ancho)
        if WowF.seccionLegacy then F.correr(WowF.seccionLegacy, p, F.h); F.cerrar() end
      end
    else
      vistaMas(k, p, y, ancho)
    end
  end
  m:SetHeight(math.max(1, k.alto))
  return m, k.alto, k.textos
end
