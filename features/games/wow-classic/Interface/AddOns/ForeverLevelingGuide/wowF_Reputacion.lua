-- wowF Reputacion: guia de reputacion con las facciones de WoW Forever (16-oct).
--   * Como funciona la reputacion (rangos, bonos: Legacy Diplomat; Diplomacy de Human no existe en WoW Forever).
--   * "Recomendadas para ti" segun tu objetivo (fabricar / oro / pvp), clase, nivel, profesiones y faccion, con el porque.
--   * Cada faccion de TU bando (y las neutrales): tu rango (leido del juego), barra en texto, como subirla a tu nivel
--     (zonas con misiones de tu nivel y cuanta reputacion dan), recompensas por rango (lo que te sirve en verde) y clic = ruta.
-- Datos: WowFReputacion (wowF_Reputacion_Datos.lua, generado por herramientas/generar-reputaciones.mjs desde Wowhead /forever
-- y herramientas/fuente/reputaciones.json). Sin dato de WoW Forever = aviso "aun no hay datos de WoW Forever; pendiente de actualizar".

WowF = WowF or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local function D() return WowFReputacion end
local function sinDatos() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end

-- Rangos del juego (nombres en ingles, como en el cliente)
local RANGO = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
-- Recetas (clase de objeto 9): subclase -> id de la profesion
local RECETA_PROF = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185, [6] = 171, [7] = 129, [8] = 333, [9] = 356 }

-- ----- Quien eres -----
local P = {}
function P.lado()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return "H" elseif f == "Alliance" then return "A" end
  return nil
end
function P.nivel() return tonumber(UnitLevel and UnitLevel("player")) or 1 end
function P.clase()
  if not UnitClass then return nil, nil end
  local _, token, id = UnitClass("player")
  return token, tonumber(id)
end
function P.raza()
  if not UnitRace then return nil end
  local _, _, id = UnitRace("player")
  return tonumber(id)
end
-- bit n (1 = el primero) de una mascara de Wowhead (0 = sin restriccion)
function P.bit(mascara, n)
  mascara, n = tonumber(mascara) or 0, tonumber(n)
  if mascara == 0 then return true end
  if not n or n < 1 then return true end
  return math.floor(mascara / (2 ^ (n - 1))) % 2 == 1
end
function P.profs()
  local t = {}
  if WowF.profesiones then
    local ok, lista = pcall(WowF.profesiones)
    if ok and type(lista) == "table" then for _, x in ipairs(lista) do if x.id then t[x.id] = tonumber(x.rango) or 0 end end end
  end
  return t
end
function P.competencias()
  local token = P.clase()
  return WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[token or ""]
end
-- Es de tu bando? (N = neutral, para todos)
function P.deMiLado(f, l) return f.lado == "N" or (l ~= nil and f.lado == l) end
local function miles(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local sep = L(".", ",")
  local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return r
end

-- ----- Tu reputacion con una faccion, leida del juego -----
-- Devuelve { rango = 1-8, nombre, cur, max } ; nil + "error" si no se pudo leer ; nil + "nueva" si aun no la conoces
function WowF.repEstado(id)
  local num = function(v) return tonumber(WowF.numero and WowF.numero(v) or v) end
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
    if ok and type(d) == "table" then
      local okc, r = pcall(function()
        local rango = num(d.reaction)
        local base, sig, ahora = num(d.currentReactionThreshold), num(d.nextReactionThreshold), num(d.currentStanding)
        if not rango then return nil end
        local cur, max
        if base and sig and ahora then cur, max = ahora - base, sig - base end
        return { rango = rango, nombre = RANGO[rango] or "?", cur = cur, max = max }
      end)
      if okc and r then return r end
      if okc then return nil, "error" end
    elseif ok and d == nil then
      -- puede faltar porque no la conoces: se prueba la API vieja antes de decidir
    elseif not ok then return nil, "error" end
  end
  if GetFactionInfoByID then
    local ok, nombre, _, rango, bMin, bMax, bVal = pcall(GetFactionInfoByID, id)
    if not ok then return nil, "error" end
    if nombre == nil then return nil, "nueva" end
    local okc, r = pcall(function()
      local rg, mn, mx, v = num(rango), num(bMin), num(bMax), num(bVal)
      if not rg then return nil end
      local cur, max
      if mn and mx and v then cur, max = v - mn, mx - mn end
      return { rango = rg, nombre = RANGO[rg] or "?", cur = cur, max = max }
    end)
    if okc and r then return r end
    return nil, "error"
  end
  if C_Reputation and C_Reputation.GetFactionDataByID then return nil, "nueva" end
  return nil, "error"
end
-- "Honored 1.200/12.000" (o el aviso)
function WowF.repTexto(id)
  local e, por = WowF.repEstado(id)
  if not e then
    if por == "nueva" then return GRIS .. L("aún no la conoces (aparece al ganar tu primera reputación)", "not discovered yet (it shows up with your first reputation)") .. "|r" end
    return GRIS .. L("no se pudo leer", "could not be read") .. "|r"
  end
  local col = (e.rango >= 5 and VERDE) or (e.rango == 4 and BLANCO) or NARANJA
  local barra = ""
  if e.cur and e.max and e.max > 0 then
    local n = math.max(0, math.min(10, math.floor(e.cur / e.max * 10 + 0.5)))
    barra = " " .. GRIS .. "[" .. "|r" .. VERDE .. string.rep("=", n) .. "|r" .. GRIS .. string.rep("-", 10 - n) .. "]|r " .. BLANCO .. miles(e.cur) .. "/" .. miles(e.max) .. "|r"
  elseif e.rango == 8 then barra = ""
  end
  return col .. e.nombre .. "|r" .. barra
end

-- ----- Misiones y zonas para subirla -----
-- Misiones de tu bando, clase y raza: ya (pide tu nivel o menos) y pronto (hasta 5 niveles mas)
function WowF.repMisiones(f, N)
  local l, raza = P.lado(), P.raza()
  local _, clase = P.clase()
  local ya, pronto = {}, {}
  local ladoN = (l == "A" and 1) or (l == "H" and 2) or nil
  for _, q in ipairs(f.q or {}) do
    local s = tonumber(q[10]) or 3
    local okLado = s == 3 or ladoN == nil or s == ladoN
    if okLado and P.bit(q[8], clase) and P.bit(q[9], raza) and (q[4] or 0) >= N - 6 then
      if (q[3] or 1) <= N then ya[#ya + 1] = q elseif (q[3] or 1) <= N + 5 then pronto[#pronto + 1] = q end
    end
  end
  return ya, pronto
end
local function nombreZona(z)
  if not z or z == 0 then return nil end
  return D() and D().zonas and D().zonas[z] or nil
end
-- Agrupa por zona: { z, n = misiones, rep = suma, d = nivel min, h = nivel max, maz = true si es una mazmorra }
function WowF.repZonas(lista)
  local por, orden = {}, {}
  for _, q in ipairs(lista) do
    local clave = (q[6] and q[6] > 0) and q[6] or (q[7] ~= "" and q[7]) or "otras"
    local g = por[clave]
    if not g then g = { z = clave, n = 0, rep = 0, d = 99, h = 0, maz = q[7] == "maz", q = {} }; por[clave] = g; orden[#orden + 1] = g end
    g.n, g.rep = g.n + 1, g.rep + (q[5] or 0)
    g.d, g.h = math.min(g.d, q[3] or 1), math.max(g.h, q[4] or 1)
    g.q[#g.q + 1] = q
  end
  table.sort(orden, function(a, b) return a.rep > b.rep end)
  return orden
end
local function textoZona(g)
  if type(g.z) == "number" then return nombreZona(g.z) or ("zona " .. g.z) end
  if g.z == "clase" then return L("misiones de tu clase", "your class quests") end
  if g.z == "jcj" then return L("campos de batalla", "battlegrounds") end
  if g.z == "feria" then return "Darkmoon Faire" end
  return L("otras misiones", "other quests")
end

-- ----- Ir a un sitio (ruta paso a paso; si no hay ruta, alfiler) -----
local function irA(dest, para)
  if not dest or not dest.m then return false end
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  print(AZUL .. Y(L("Reputación: ve a ", "Reputation: go to ") .. ORO .. dest.n .. "|r" .. GRIS .. ", " .. (dest.z or "") .. " " .. dest.x .. ", " .. dest.y .. "|r"))
  local destino = { n = dest.n, m = dest.m, x = dest.x, y = dest.y, z = dest.z, lugar = true, final = {
    titulo = dest.n, ventana = ORO .. L("Reputación", "Reputation") .. "|r", texto = Y(para), llegada = Y(para) } }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then pcall(WowF.marcar, { m = dest.m, x = dest.x, y = dest.y, n = dest.n, z = dest.z, lugar = true }) end
  if dest.npc and WowF.marcarNPC then pcall(WowF.marcarNPC, { n = dest.n, npc = dest.npc, sub = L("Reputación", "Reputation") }) end
  return true
end
-- Al vendedor de recompensas de la faccion
function WowF.irVendedorRep(f, npcId)
  local v = f and f.v and f.v[npcId]
  if not v or not v.m then
    print(AZUL .. NARANJA .. Y(L("no tengo la posicion de ", "I do not have the position of ") .. ((v and v.n) or "?") .. ": " .. sinDatos() .. ".") .. "|r")
    return false
  end
  return irA({ n = v.n, m = v.m, x = v.x, y = v.y, z = v.z, npc = npcId },
    L("compra las recompensas de ", "buy the rewards of ") .. f.n .. L(" (según tu rango).", " (depends on your rank)."))
end
-- A una zona con misiones: al pueblo de tu bando en esa zona (WowFZonas) o a la mazmorra
function WowF.irZonaRep(f, g)
  local l = P.lado()
  if type(g.z) == "number" then
    for _, z in ipairs(WowFZonas or {}) do
      if z.id == g.z then
        local b = l and z[l]
        local pu = b and b.pueblos and b.pueblos[1]
        if pu and z.m then
          return irA({ n = pu.n or pu.npc or z.n, m = z.m, x = pu.x, y = pu.y, z = z.n },
            L("haz las misiones de ", "do the quests of ") .. z.n .. L(": dan reputación con ", ": they give reputation with ") .. f.n .. ".")
        end
      end
    end
    local nombre = nombreZona(g.z)
    for _, m in ipairs(WowFMazmorras or {}) do
      if nombre and m.n == nombre and WowF.irAMazmorra then pcall(WowF.irAMazmorra, m); return true end
    end
    print(AZUL .. Y(L("Las misiones están en ", "The quests are in ") .. ORO .. (nombre or "?") .. "|r" .. GRIS .. L(" (sin punto de llegada en los datos: busca a quién da misiones allí).", " (no arrival point in the data: look for quest givers there).") .. "|r"))
    return false
  end
  print(AZUL .. Y(textoZona(g) .. ": " .. L("revisa tu registro de misiones y a tu entrenador de clase.", "check your quest log and your class trainer.")))
  return false
end
-- Clic en la faccion: al vendedor si hay; si no, a la mejor zona de tu nivel
function WowF.irFaccionRep(f)
  for npcId, v in pairs(f.v or {}) do if v.m then return WowF.irVendedorRep(f, npcId) end end
  local ya = WowF.repMisiones(f, P.nivel())
  local zs = WowF.repZonas(ya)
  if zs[1] then return WowF.irZonaRep(f, zs[1]) end
  print(AZUL .. NARANJA .. Y(f.n .. ": " .. sinDatos() .. ".") .. "|r")
  return false
end

-- ----- Recompensas que te sirven -----
-- Devuelve true (te sirve), false (no), y el porque corto
function WowF.repTeSirve(o, N, profs, comp)
  local cl, sc, rl = o[6], o[7], o[5] or 0
  if cl == 9 then
    local prof = RECETA_PROF[sc]
    if prof and profs[prof] then return true, L("receta de tu profesion", "recipe for your profession") end
    return false, nil
  elseif cl == 4 or cl == 2 then
    local t = cl == 4 and (comp and comp.armaduras) or (comp and comp.armas)
    if cl == 4 and sc == 0 then return rl <= N + 10, nil end
    local desde = t and t[sc]
    if desde ~= nil and desde <= math.max(N, rl) and rl <= N + 10 then return true, L("la puedes llevar", "you can wear it") end
    return false, nil
  end
  return false, nil
end

-- ----- Recomendadas para ti -----
-- Puntos por faccion segun objetivo; devuelve lista ordenada de { f, puntos, porque = {textos} }
function WowF.repRecomendadas(objetivo, N)
  local d = D()
  if not d then return {} end
  local l, raza = P.lado(), P.raza()
  local profs, comp = P.profs(), P.competencias()
  local res = {}
  for _, f in ipairs(d.f or {}) do
    if P.deMiLado(f, l) and f.datos then
      local pts, por = 0, {}
      local ya = WowF.repMisiones(f, N)
      local rep = 0
      for _, q in ipairs(ya) do rep = rep + (q[5] or 0) end
      if #ya > 0 then
        pts = pts + math.min(4, rep / 1000)
        por[#por + 1] = Y(#ya .. L(" misiones de tu nivel (+", " quests at your level (+") .. miles(rep) .. L(" de reputación)", " reputation)"))
      end
      local recetas, equipo = 0, 0
      for _, o in ipairs(f.it or {}) do
        local sirve, porque = WowF.repTeSirve(o, N, profs, comp)
        if sirve and o[6] == 9 then recetas = recetas + 1 elseif sirve and porque then equipo = equipo + 1 end
      end
      if f.raza then for _, r in ipairs(f.raza) do if r == raza then pts = pts + 1; por[#por + 1] = L("es la ciudad de tu raza", "it is your race's capital") end end end
      if objetivo == "fabricar" or objetivo == "oro" then
        if recetas > 0 then
          pts = pts + 3 + recetas * 0.3
          por[#por + 1] = Y(recetas .. (objetivo == "oro" and L(" recetas de tus profesiones para fabricar y vender", " recipes of your professions to craft and sell")
            or L(" recetas de tus profesiones", " recipes of your professions")))
        end
        if f.prof and N >= (f.nv or 0) then pts = pts + 3; por[#por + 1] = L("da Merchant's Favor y recetas de profesion", "gives Merchant's Favor and profession recipes") end
        if objetivo == "fabricar" and equipo > 0 then pts = pts + 1; por[#por + 1] = Y(equipo .. L(" piezas que puedes llevar", " pieces you can wear")) end
      elseif objetivo == "pvp" then
        if f.pvp then pts = pts + 5; por[#por + 1] = L("facción de JcJ: equipo para pelear contra jugadores", "PvP faction: gear for fighting players") end
        if equipo > 0 then pts = pts + 1 + equipo * 0.2; por[#por + 1] = Y(equipo .. L(" piezas que puedes llevar", " pieces you can wear")) end
      else
        if equipo > 0 then pts = pts + 1; por[#por + 1] = Y(equipo .. L(" piezas que puedes llevar", " pieces you can wear")) end
        if recetas > 0 then pts = pts + 1; por[#por + 1] = Y(recetas .. L(" recetas de tus profesiones", " recipes of your professions")) end
      end
      if pts > 0 then res[#res + 1] = { f = f, puntos = pts, porque = por } end
    end
  end
  table.sort(res, function(a, b) return a.puntos > b.puntos end)
  return res
end

-- ----- Seccion para el Libro (pestaña de Profesiones u otra) -----
local GRUPOS = {
  { "ciudad", "Tu ciudad y aliadas", "Your capital and allies" },
  { "neutral", "Neutrales", "Neutral" },
  { "prof", "Profesiones", "Professions" },
  { "pvp", "PvP", "PvP" },
}
local NOMBRE_OBJ = { fabricar = { "fabricarte el equipo", "crafting your gear" }, oro = { "ganar oro", "making gold" }, pvp = { "PvP", "PvP" } }

local function pintarFaccion(f, h, N, profs, comp)
  local icono = h.icono and h.icono("Interface\\Icons\\Achievement_Reputation_01") or nil
  h.item({ texto = Y(ORO .. f.n .. "|r  " .. WowF.repTexto(f.id)), sub = Y(GRIS .. (WowF.enIngles and WowF.enIngles() and f.en or f.es) .. "|r"),
    icono = icono, accion = function() WowF.irFaccionRep(f) end })
  if not f.datos then
    h.nota(Y(NARANJA .. f.n .. ": " .. sinDatos() .. ".|r"))
    return
  end
  if (f.nv or 0) > N then h.nota(Y(NARANJA .. L("Se abre a nivel ", "Unlocks at level ") .. f.nv .. ".|r")) end
  -- Como subirla
  for _, c in ipairs(f.como or {}) do h.nota(Y(CELESTE .. "» |r" .. (WowF.enIngles and WowF.enIngles() and c[2] or c[1]))) end
  local ya, pronto = WowF.repMisiones(f, N)
  local zs = WowF.repZonas(ya)
  if #zs > 0 then
    h.nota(Y(VERDE .. L("Súbela ya (misiones de tu nivel):", "Raise it now (quests at your level):") .. "|r"))
    for i = 1, math.min(3, #zs) do
      local g = zs[i]
      local ej = g.q[1] and g.q[1][2] or ""
      h.item({ texto = Y(BLANCO .. textoZona(g) .. "|r" .. GRIS .. ": " .. g.n .. L(" misiones, +", " quests, +") .. miles(g.rep) .. L(" (nivel ", " (level ") .. g.d .. "-" .. g.h .. ")|r"),
        sub = Y(GRIS .. L("p. ej. ", "e.g. ") .. ej .. (g.maz and L(" (mazmorra)", " (dungeon)") or "") .. "|r"), sangria = 12, chico = true,
        accion = function() WowF.irZonaRep(f, g) end })
    end
  elseif #pronto > 0 then
    local rep = 0
    for _, q in ipairs(pronto) do rep = rep + (q[5] or 0) end
    h.nota(Y(NARANJA .. L("Próximas al subir: ", "Coming up as you level: ") .. #pronto .. L(" misiones (+", " quests (+") .. miles(rep) .. L(") desde nivel ", ") from level ") .. (pronto[1][3] or N) .. ".|r"))
  elseif #(f.q or {}) == 0 then
    h.nota(Y(GRIS .. L("Misiones con reputación: ", "Quests with reputation: ") .. sinDatos() .. ".|r"))
  else
    h.nota(Y(GRIS .. L("No quedan misiones de tu nivel que den esta reputación.", "No quests at your level give this reputation.") .. "|r"))
  end
  -- Recompensas por rango
  if #(f.it or {}) == 0 then
    h.nota(Y(GRIS .. L("Recompensas: ", "Rewards: ") .. sinDatos() .. ".|r"))
  else
    local porRango = {}
    for _, o in ipairs(f.it) do local r = o[4] or 4; porRango[r] = porRango[r] or {}; table.insert(porRango[r], o) end
    for r = 4, 8 do
      local t = porRango[r]
      if t then
        local partes, utiles = {}, 0
        for _, o in ipairs(t) do
          local sirve = WowF.repTeSirve(o, N, profs, comp)
          if sirve then utiles = utiles + 1 end
          if #partes < 6 then partes[#partes + 1] = (sirve and VERDE or GRIS) .. o[2] .. "|r" end
        end
        local resto = #t > 6 and (GRIS .. L(" y ", " and ") .. (#t - 6) .. L(" más", " more") .. "|r") or ""
        local vend = t[1][9]
        h.item({ texto = Y(ORO .. (RANGO[r] or "?") .. "|r" .. GRIS .. ": " .. #t .. L(" recompensas", " rewards") .. (utiles > 0 and (", " .. VERDE .. utiles .. L(" te sirven", " useful for you") .. "|r") or "") .. "|r"),
          sub = Y(table.concat(partes, GRIS .. ", |r") .. resto), sangria = 12, chico = true,
          icono = h.icono and t[1][1] and h.icono(nil, t[1][1]) or nil,
          accion = (vend and vend > 0) and function() WowF.irVendedorRep(f, vend) end or nil })
      end
    end
  end
  for _, a in ipairs(f.avisos or {}) do h.nota(Y(NARANJA .. (WowF.enIngles and WowF.enIngles() and a[2] or a[1]) .. "|r")) end
end

function WowF.seccionReputacion(p, h)
  local d = D()
  h.cab(ORO .. L("Reputación", "Reputation") .. "|r")
  if not d then
    h.nota(GRIS .. L("Faltan los datos de reputación: reinstala el addon.", "Reputation data is missing: reinstall the addon.") .. "|r")
    return
  end
  local l, N = P.lado(), P.nivel()
  local objetivo = (p and p.objetivo) or (WowF.objetivo and select(2, pcall(WowF.objetivo))) or nil
  if type(objetivo) ~= "string" then objetivo = nil end
  -- 1) Como funciona
  h.nota(Y(BLANCO .. L("Cada facción te tiene en un rango: ", "Each faction ranks you: ") .. "|r" .. GRIS .. table.concat(RANGO, " » ") .. "|r"))
  h.nota(Y(GRIS .. L("Subes con misiones (y algunas facciones con entregas o con su moneda). Cada rango abre recompensas en su vendedor. Tu barra y los puntos de cada rango los lee el addon de tu juego.",
    "You raise it with quests (and some factions with turn-ins or their currency). Each rank unlocks rewards at its vendor. Your bar and the points of each rank are read from your game.") .. "|r"))
  local rangoDip = WowF.legacyRango and tonumber((select(2, pcall(WowF.legacyRango, d.diplomat)))) or nil
  local valorDip = WowF.legacyValor and tonumber((select(2, pcall(WowF.legacyValor, d.diplomat)))) or nil
  for _, b in ipairs(d.bonos or {}) do
    local txt = WowF.enIngles and WowF.enIngles() and b.en or b.es
    if b.id == "legacy-diplomat" then
      if rangoDip and rangoDip > 0 then txt = txt .. VERDE .. L(" Tienes rango ", " You have rank ") .. rangoDip .. (valorDip and (": +" .. valorDip .. "%") or "") .. ".|r"
      else txt = txt .. GRIS .. L(" No lo tienes (o no se pudo leer).", " You do not have it (or it could not be read).") .. "|r" end
    end
    h.nota(Y((b.existe and CELESTE or GRIS) .. txt .. "|r"))
  end
  if not l then
    h.nota(GRIS .. L("Elige facción primero: las reputaciones dependen de ella.", "Choose a faction first: reputations depend on it.") .. "|r")
    return
  end
  local profs, comp = P.profs(), P.competencias()
  -- 2) Recomendadas para ti
  local nom = objetivo and NOMBRE_OBJ[objetivo]
  h.cab(ORO .. L("Recomendadas para ti", "Recommended for you") .. "|r" .. GRIS .. (nom and (" (" .. L("objetivo: ", "goal: ") .. L(nom[1], nom[2]) .. ")") or "") .. "|r")
  local rec = WowF.repRecomendadas(objetivo, N)
  if #rec == 0 then
    h.nota(Y(GRIS .. L("Ninguna facción de tu bando tiene algo para ti a tu nivel: ", "No faction of your side has something for you at your level: ") .. sinDatos() .. ".|r"))
  end
  for i = 1, math.min(3, #rec) do
    local r = rec[i]
    h.item({ texto = Y(VERDE .. i .. ". |r" .. ORO .. r.f.n .. "|r  " .. WowF.repTexto(r.f.id)),
      sub = Y(GRIS .. L("Por qué: ", "Why: ") .. table.concat(r.porque, "; ") .. ".|r"),
      icono = h.icono and h.icono("Interface\\Icons\\Achievement_Reputation_01") or nil,
      accion = function() WowF.irFaccionRep(r.f) end })
  end
  -- 3) Cada faccion de tu bando, por grupos
  for _, gr in ipairs(GRUPOS) do
    local hay = false
    for _, f in ipairs(d.f or {}) do
      if f.g == gr[1] and P.deMiLado(f, l) then
        if not hay then h.cab(ORO .. L(gr[2], gr[3]) .. "|r"); hay = true end
        pintarFaccion(f, h, N, profs, comp)
        if h.separador then h.separador() end
      end
    end
  end
  -- 4) Avisos
  h.nota(Y(GRIS .. L("Datos de WoW Forever (Wowhead /forever, build ", "WoW Forever data (Wowhead /forever, build ") .. (d.build or "?")
    .. L("). La reputación de cada misión es la de la fuente; lo que aún no está confirmado se dice y se actualizará en próximas actualizaciones.",
      "). Each quest's reputation is the source's; anything unconfirmed is marked and will be updated in future updates.") .. "|r"))
end

-- /wowf reputacion | reputation | rep : resumen en el chat (recomendadas)
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(msg, ...)
    local c = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    if c == "reputacion" or c == "reputation" or c == "rep" then
      local objetivo = WowF.objetivo and select(2, pcall(WowF.objetivo)) or nil
      local rec = WowF.repRecomendadas(type(objetivo) == "string" and objetivo or nil, P.nivel())
      print(AZUL .. ORO .. L("Reputación recomendada para ti:", "Reputation recommended for you:") .. "|r")
      if #rec == 0 then print(AZUL .. GRIS .. sinDatos() .. "|r") end
      for i = 1, math.min(3, #rec) do
        print(AZUL .. Y(i .. ". " .. ORO .. rec[i].f.n .. "|r " .. WowF.repTexto(rec[i].f.id) .. GRIS .. " - " .. table.concat(rec[i].porque, "; ") .. "|r"))
      end
      return
    end
    if ordenAnterior then return ordenAnterior(msg, ...) end
  end
end
