-- wowF Consumibles (10-oct-2026, 4.23; Andy: "los mejores consumibles para PvP y PvE, comprados o crafteados, para cada clase y raza").
-- Datos: wowF_Consumibles_Datos.lua (generado por herramientas/generar-consumibles.mjs; cliente de la beta + Wowhead /forever, nada de Classic).
-- Se recalcula EN VIVO: tu nivel (lo que ya puedes usar y lo siguiente al subir), los pesos de tu rama (que estadistica te sirve),
-- tu clase (mana / rabia / arma), tu faccion (solo vendedores tuyos) y tus profesiones (lo que te fabricas tu).
-- Lo que recomiendan las guias de WoW Forever para tu rama sale primero, con la fuente. Clic: vendedor = ruta; si no, como conseguirlo
-- y el precio de la casa de subastas si lo conoces. Seccion en "BiS 30" (WowF.seccionConsumibles) y /wowf consumibles.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local ORO, VERDE, GRIS, NARANJA, CELESTE, MORADO = "|cffffd100", "|cff33ff66", "|cff999999", "|cffff9933", "|cff66ccff", "|cffcc66ff"
local AZUL = "|cff33ccffForever Guide|r: "
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local SIN_DATOS_ES, SIN_DATOS_EN = "aún no hay datos de WoW Forever; se actualizará en próximas actualizaciones", "there is no WoW Forever data yet; it will be updated in future updates"
local PROF = { Alchemy = 171, Blacksmithing = 164, Enchanting = 333, Engineering = 202, Cooking = 185, ["First Aid"] = 129, Leatherworking = 165, Tailoring = 197 }
local MANA = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true }

local function datos() return WowFConsumibles end
local function miFac()
  local f = WowF.llamar and WowF.llamar(UnitFactionGroup, "player") or (UnitFactionGroup and UnitFactionGroup("player"))
  return f == "Horde" and "H" or "A"
end
-- 12-oct (auditoria): sin volver a llamar a UnitLevel a pelo si WowF.llamar devolvio nil (valor secreto)
local function nivelPj()
  if WowF.llamar then return tonumber(WowF.llamar(UnitLevel, "player")) or 1 end
  local ok, n = pcall(function() return tonumber(UnitLevel("player")) end)
  return ok and n or 1
end
local function miClase(p)
  local c = p and p.clase
  if not c then local ok, _, tk = pcall(UnitClass, "player"); c = ok and tk or nil end
  return c and tostring(c):upper() or ""
end
local function rango(prof)
  local id = PROF[prof]
  if not (id and WowF.rangoProfesion) then return nil end
  local ok, r = pcall(WowF.rangoProfesion, id)
  return ok and tonumber(r) or nil
end
-- Nivel desde el que una profesion llega a ese rango (topes de WowFDatos.caps)
local function nivelParaRango(r)
  for _, c in ipairs((WowFDatos and WowFDatos.caps) or {}) do if r <= c[2] then return c[1] end end
  return 35
end
local function dinero(c) if WowF.avisoBotinDinero then return WowF.avisoBotinDinero(c) end return tostring(c) .. "c" end
local function precio(id)
  if not WowF.precioSubasta then return nil end
  local link
  if GetItemInfo then local ok, _, l = pcall(GetItemInfo, id); if ok then link = l end end
  local ok, p, fuente = pcall(WowF.precioSubasta, link or ("item:" .. id), id)
  if ok and p and p > 0 then return p, fuente end
  return nil
end
local function icono(id) -- 12-oct: cliente primero (sin el signo de interrogacion), luego WowFDatos.obj del mismo id
  return (WowF.iconoObjeto and WowF.iconoObjeto(id)) or "Interface\\Icons\\INV_Potion_51"
end

-- Puntos de un consumible con los pesos de tu rama
local function puntos(x, pesos)
  if not (x.st and pesos) then return 0 end
  local p = 0
  for k, v in pairs(x.st) do
    if k == "ar" then p = p + v * (pesos.ar or 0)
    elseif k == 45 then p = p + v * math.max(pesos[45] or 0, pesos[42] or 0)
    elseif k == 38 then p = p + v * math.max(pesos[38] or 0, pesos[39] or 0)
    else p = p + v * (pesos[k] or 0) end
  end
  return p
end

-- Vendedores de tu faccion (o neutrales)
local function vendedores(x)
  local fac, r = miFac(), {}
  for _, v in ipairs(x.vd or {}) do if v[5] == fac or v[5] == "N" then r[#r + 1] = { npc = v[1], m = v[2], x = v[3], y = v[4], z = v[6] } end end
  return r
end
-- Se puede conseguir sin ser de la otra faccion
local function conseguible(x)
  if x.cl then return true end
  if x.fab then return true end
  if #vendedores(x) > 0 then return true end
  return x.otro ~= nil
end

-- Lo mejor de una categoria: el que ya puedes usar y el siguiente al subir (hasta el tope de la beta)
-- valor(x) ordena; filtro(x) opcional
local function mejorDe(cat, valor, filtro)
  local D, nivel = datos(), nivelPj()
  if not D then return nil end
  local ahora, va, prox, vp
  for id, x in pairs(D.lista) do
    if x.c == cat and conseguible(x) and (not filtro or filtro(x)) then
      local v = valor(x)
      if v and v > 0 then
        if (x.rl or 0) <= nivel then
          if not va or v > va or (v == va and id < ahora) then ahora, va = id, v end
        elseif (x.rl or 0) <= (D.tope or 30) then
          if not vp or v > vp or (v == vp and (x.rl < D.lista[prox].rl)) then prox, vp = id, v end
        end
      end
    end
  end
  if prox and va and vp <= va then prox = nil end
  return ahora, prox
end
local function porValor(x) return x.v or 0 end

-- Como se consigue (texto) y si te lo fabricas tu
local function comoSeConsigue(id, x)
  local partes = {}
  if x.cl then
    if x.cl == "WARLOCK" then
      partes[#partes + 1] = L("Lo crea el Warlock (Create Healthstone). Si no eres Warlock, pídeselo a uno de tu grupo.", "Made by Warlocks (Create Healthstone). If you are not a Warlock, ask one in your group.")
    end
    return table.concat(partes, "\n"), false
  end
  local tuyo = false
  if x.fab then
    local prof, r = x.fab[1], x.fab[2]
    local mio = rango(prof)
    local desde = nivelParaRango(r)
    if mio and mio >= r then
      tuyo = true
      partes[#partes + 1] = VERDE .. L("Te lo fabricas tú: " .. prof .. " " .. r .. " (tienes " .. mio .. ").", "You can make it: " .. prof .. " " .. r .. " (you have " .. mio .. ").") .. "|r"
    elseif mio then
      partes[#partes + 1] = L("Fabricado: " .. prof .. " " .. r .. " (tienes " .. mio .. "; llegas al subir la profesión).", "Crafted: " .. prof .. " " .. r .. " (you have " .. mio .. "; you get there by leveling the profession).")
    else
      partes[#partes + 1] = L("Fabricado: " .. prof .. " " .. r .. " (un personaje de nivel " .. desde .. " o más puede hacerlo).", "Crafted: " .. prof .. " " .. r .. " (a level " .. desde .. "+ character can make it).")
    end
    if x.fab[3] and x.fab[3]:find("patron", 1, true) then
      partes[#partes] = partes[#partes] .. " " .. GRIS .. L("Receta aparte (no la enseña el entrenador).", "Separate recipe (not taught by the trainer).") .. "|r"
    end
  end
  local vd = vendedores(x)
  if #vd > 0 then
    local v = vd[1]
    if WowF._bisMasCerca then local ok, c = pcall(WowF._bisMasCerca, vd); if ok and c then v = c end end
    partes[#partes + 1] = L("Lo vende " .. v.npc .. " (" .. (v.z or "?") .. ")", "Sold by " .. v.npc .. " (" .. (v.z or "?") .. ")") .. (#vd > 1 and L(" y " .. (#vd - 1) .. " más", " and " .. (#vd - 1) .. " more") or "") .. "."
  end
  if not x.fab and #vd == 0 and x.otro then
    local o = x.otro
    local es = o:gsub("botin", "botín"):gsub("mision", "misión")
    local en = o:gsub("botin", "loot"):gsub("mision", "quest")
    partes[#partes + 1] = L("Se consigue de: " .. es .. ".", "You get it from: " .. en .. ".")
  end
  if not tuyo and #vd == 0 then
    local p = precio(id)
    if p then partes[#partes + 1] = L("Casa de subastas: " .. dinero(p) .. " (último precio que viste).", "Auction House: " .. dinero(p) .. " (last price you saw).")
    else partes[#partes + 1] = L("Búscalo en la casa de subastas.", "Look for it in the Auction House.") end
  end
  return table.concat(partes, "\n"), tuyo
end

-- ----- Lo que te toca: lista PvE y PvP -----
-- Cada fila: { id, cat, prox, porEs, porEn, reco }
function WowF.consumiblesDe(p)
  local D = datos()
  if not D then return nil end
  p = p or (WowF.planActual and WowF.planActual()) or {}
  local pesos = p.pesos or {}
  local clase = miClase(p)
  local nivel = nivelPj()
  local mana = MANA[clase] == true
  local lanzador = math.max(pesos[45] or 0, pesos[42] or 0, pesos[41] or 0) >= 0.9
  local sanador = (pesos[41] or 0) >= 1 and (pesos[42] or 0) < 0.5
  local cuerpo = (pesos.dps or 0) > 1 and clase ~= "HUNTER"
  local rabia = clase == "WARRIOR" or (clase == "DRUID" and (pesos[40] or 0) > 0)
  local pve, pvp = {}, {}
  local function add(t, cat, porEs, porEn, valor, filtro)
    local a, n = mejorDe(cat, valor or porValor, filtro)
    if a or n then t[#t + 1] = { id = a, prox = n, cat = cat, porEs = porEs, porEn = porEn } end
  end
  local function stat(x) return puntos(x, pesos) end
  -- PvE
  add(pve, "vida", "Poción de vida para salvarte en un apuro.", "Health potion to save you in a pinch.")
  if mana then add(pve, "mana", "Poción de maná para no quedarte seco.", "Mana potion so you do not run dry.") end
  if rabia then add(pve, "rabia", "Rabia al instante para abrir la pelea.", "Instant rage to open the fight.") end
  add(pve, "pocion30", "Poción de 30 s nueva de Forever: úsala en el jefe.", "New Forever 30 sec potion: use it on the boss.", stat)
  add(pve, "elixir", "El elixir que más sube tus estadísticas.", "The elixir that raises your stats the most.", stat)
  -- scrolls: uno por estadistica distinta (se suman entre si)
  do
    local usados = {}
    for _ = 1, 2 do
      local a, n = mejorDe("scroll", stat, function(x)
        for k in pairs(x.st or {}) do if usados[k] then return false end end
        return true
      end)
      if not (a or n) then break end
      local x = D.lista[a or n]
      for k in pairs(x.st or {}) do usados[k] = true end
      pve[#pve + 1] = { id = a, prox = n, cat = "scroll", porEs = "Scroll: se suma al elixir. Usalo antes de pelear: desde el parche del 15-oct gasta el tiempo global.", porEn = "Scroll: it stacks with the elixir. Use it before the fight: since the Oct 15 patch it triggers the global cooldown." }
    end
  end
  add(pve, "comidaBuff", "Comida con Well Fed para tu estadística.", "Food with Well Fed for your stat.", stat)
  if mana then add(pve, "bebida", "La bebida que más maná te da.", "The drink that gives you the most mana.") end
  add(pve, "comida", "Comida para recuperar vida entre peleas.", "Food to recover health between fights.")
  add(pve, "venda", "Venda (First Aid): cura sin gastar maná.", "Bandage (First Aid): heals without using mana.")
  if cuerpo then
    add(pve, "afilar", "Para armas de filo (Sword, Axe, Dagger, Polearm).", "For sharp weapons (Sword, Axe, Dagger, Polearm).")
    add(pve, "contrapeso", "Para armas romas (Mace, Staff).", "For blunt weapons (Mace, Staff).")
  elseif sanador then add(pve, "aceiteMana", "Aceite para el arma de un sanador.", "Weapon oil for a healer.", stat)
  elseif lanzador then add(pve, "aceiteHechizo", "Aceite para el arma de un lanzador.", "Weapon oil for a caster.", stat) end
  add(pve, "piedraVida", "Piedra de vida del Warlock: no comparte tiempo con las pociones.", "Warlock Healthstone: it does not share a cooldown with potions.")
  -- PvP
  add(pvp, "libre", "Tómala ANTES: no quita lo que ya tienes encima. Está en todas las guías PvP de WoW Forever.", "Drink it BEFORE: it does not remove effects already on you. It is in every WoW Forever PvP guide.")
  add(pvp, "descolorida", "Cura el DOBLE al instante; luego el 75 % vuelve como veneno o enfermedad. Vale la pena si puedes quitarlo (Paladin con Purify, según Icy Veins).",
    "Heals DOUBLE instantly; then 75% comes back as a poison or disease. Worth it if you can remove it (Paladin with Purify, per Icy Veins).")
  add(pvp, "ron", "Más Stamina (foreverchanges, PvP).", "More Stamina (foreverchanges, PvP).", stat)
  add(pvp, "polvo", "Control: duerme a un enemigo (foreverchanges, PvP).", "Control: puts an enemy to sleep (foreverchanges, PvP).")
  add(pvp, "velocidad", "Para escapar o alcanzar.", "To escape or to catch up.")
  add(pvp, "invisible", "Para salir de una pelea perdida.", "To get out of a lost fight.")
  add(pvp, "proteccion", "Contra lanzadores (elige la escuela del rival).", "Against casters (pick the enemy's school).")
  add(pvp, "vida", "Poción de vida normal (sin el daño de después).", "Normal health potion (no damage afterwards).")
  add(pvp, "venda", "Venda entre peleas.", "Bandage between fights.")
  if rango("Engineering") then
    add(pvp, "explosivo", "Engineering: daño en área y aturdir.", "Engineering: area damage and stun.", nil, function(x) return type(x.fab) == "table" and (rango("Engineering") or 0) >= (tonumber(x.fab[2]) or 0) end)
  end
  -- Lo que recomiendan las guias de WoW Forever para tu rama: primero y marcado
  local r = D.reco and p.ramaPesos and D.reco[clase .. "|" .. tostring(p.ramaPesos)]
  local okR, _, raza = pcall(UnitRace, "player")
  local res = { pve = pve, pvp = pvp, reco = r, nivel = nivel, clase = clase, raza = okR and raza or nil }
  if r then
    for _, modo in ipairs({ "pve", "pvp" }) do
      local arriba, ya = {}, {}
      for _, id in ipairs(r[modo] or {}) do
        local x = D.lista[id]
        -- 12-oct (auditoria): lo de la guia tambien pasa por tu faccion (conseguible) y el tope de la beta
        if x and not ya[id] and conseguible(x) and (x.rl or 0) <= (D.tope or 30) then
          ya[id] = true
          local puede = (x.rl or 0) <= nivel
          arriba[#arriba + 1] = { id = puede and id or nil, prox = (not puede) and id or nil, cat = x.c, reco = true }
        end
      end
      -- lo calculado que la guia no trae (sin repetir objetos)
      for _, f in ipairs(res[modo]) do
        if not (ya[f.id or 0] or ya[f.prox or 0]) then arriba[#arriba + 1] = f end
      end
      res[modo] = arriba
    end
  end
  return res
end

-- ----- Clic: vendedor = ruta; si no, explica como conseguirlo -----
local function decir(es, en) print(Y(AZUL .. L(es, en))) end
-- Receta del objeto en WowFDatos.objetivoProf (venta, pvp, secundaria...): { mats = { { id, cantidad } } }
local function recetaDe(id)
  for _, tabla in pairs((WowFDatos and WowFDatos.objetivoProf) or {}) do
    if type(tabla) == "table" then
      for _, lista in pairs(tabla) do
        if type(lista) == "table" then
          for _, f in ipairs(lista) do
            if type(f) == "table" and f[1] == id then
              for _, v in ipairs(f) do if type(v) == "table" and type(v[1]) == "table" then return { mats = v } end end
            end
          end
        end
      end
    end
  end
  return nil
end
local function textoMats(mats)
  local partes, todo = {}, true
  for _, m in ipairs(mats or {}) do
    local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[m[1]]
    local n = (o and o[1]) or (GetItemInfo and select(2, pcall(GetItemInfo, m[1]))) or ("item " .. m[1])
    local tn = (GetItemCount and tonumber(GetItemCount(m[1], true))) or 0
    if tn < m[2] then todo = false end
    partes[#partes + 1] = m[2] .. " " .. tostring(n) .. (tn >= m[2] and (VERDE .. " (ok)|r") or (tn > 0 and (GRIS .. L(" (tienes ", " (you have ") .. tn .. ")|r") or ""))
  end
  return table.concat(partes, ", "), todo
end
-- Entrenador verificado de tu faccion que ensena ese rango (el mas cercano)
local function entrenadorDe(prof, r)
  local lista, fac = {}, miFac()
  for _, e in ipairs((WowFDatos and WowFDatos.entrenadores and WowFDatos.entrenadores[PROF[prof] or 0]) or {}) do
    if (e[5] == fac or e[5] == "N") and not (WowF.esAproximado and WowF.esAproximado(e)) and (tonumber(e[6]) or 0) >= r then
      lista[#lista + 1] = { m = e[2], x = e[3], y = e[4], e = e }
    end
  end
  if #lista == 0 then return nil end
  local c = lista[1]
  if WowF._bisMasCerca then local ok, r2 = pcall(WowF._bisMasCerca, lista); if ok and r2 then c = r2 end end
  return c.e
end
local function irEntrenador(e, prof)
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  local destino = { m = e[2], x = e[3], y = e[4], n = e[1], z = e[7], lugar = true, final = { titulo = e[1], corto = e[1], detalle = "",
    ventana = ORO .. L("Entrenador de ", "") .. prof .. L("", " trainer") .. "|r",
    texto = Y(L("Habla con " .. e[1] .. " y entrena " .. prof, "Talk to " .. e[1] .. " and train " .. prof)),
    llegada = Y(L("Habla con " .. e[1] .. " y entrena el rango siguiente de " .. prof .. ".", "Talk to " .. e[1] .. " and train the next " .. prof .. " rank.")), npc = e[1] } }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = e[1], sub = ORO .. Y(L("Entrenador de ", "") .. prof .. L("", " trainer")) .. "|r" }) end
  if WowF.viajeA then local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }); if ok and hecho then return true end end
  return WowF.marcarEntrenador and WowF.marcarEntrenador(e, prof) ~= nil
end
function WowF.irAConsumible(id)
  local D = datos()
  local x = D and D.lista[id]
  if not x then return false end
  local vd = vendedores(x)
  if #vd > 0 then
    local v = vd[1]
    if WowF._bisMasCerca then local ok, c = pcall(WowF._bisMasCerca, vd); if ok and c then v = c end end
    decir(x.n .. ": lo vende " .. v.npc .. " en " .. (v.z or "?") .. ". Te llevo allí.", x.n .. ": sold by " .. v.npc .. " in " .. (v.z or "?") .. ". Taking you there.")
    local destino = { m = v.m, x = v.x, y = v.y, n = Y(v.npc .. " (" .. x.n .. ")") }
    destino.final = { texto = Y(L("Compra " .. x.n .. " a " .. v.npc, "Buy " .. x.n .. " from " .. v.npc)), titulo = v.npc, corto = v.npc, detalle = "",
      llegada = Y(L("Compra " .. x.n .. " a " .. v.npc .. ".", "Buy " .. x.n .. " from " .. v.npc .. ".")), npc = v.npc }
    if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = v.npc, sub = "|cffffd100" .. Y(L("Consumible: ", "Consumable: ") .. x.n) .. "|r" }) end
    if WowF.viajeA then local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }); if ok and hecho then return true end end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
      return (pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(v.m, v.x / 100, v.y / 100)) end))
    end
    return false
  end
  -- 12-oct (Andy: "no que me lo ponga en el chat y ya"): sin vendedor = ventana con los pasos y botones que te llevan
  local pasos, botones, ruta = {}, {}, nil
  local function paso(es, en) pasos[#pasos + 1] = L(es, en) end
  local s = WowF.subastaCercana and WowF.subastaCercana()
  local function botonSubasta() if s then botones[#botones + 1] = { L("Llévame a la casa de subastas", "Take me to the Auction House"), function() return WowF.irASubasta(x.n) end } end end
  if x.cl == "WARLOCK" then
    if miClase() == "WARLOCK" then
      paso("Lanza Create Healthstone (libro de hechizos). Necesitas 1 Soul Shard en la bolsa.", "Cast Create Healthstone (spellbook). You need 1 Soul Shard in your bags.")
      paso("Si aún no lo tienes, apréndelo con tu entrenador de Warlock.", "If you do not have it yet, learn it from your Warlock trainer.")
      botones[#botones + 1] = { L("Llévame a mi entrenador", "Take me to my trainer"), function() return WowF.irAlEntrenadorClase and WowF.irAlEntrenadorClase("Create Healthstone") end }
    else
      paso("Solo la crea un Warlock y no se vende: pídesela a uno de tu grupo o banda.", "Only Warlocks make it and it cannot be sold: ask one in your group or raid.")
      paso("En una banda, el Warlock te la puede dar con un intercambio.", "In a raid, the Warlock can trade it to you.")
    end
  elseif x.fab then
    local prof, r = x.fab[1], x.fab[2]
    local mio = rango(prof)
    local rec = recetaDe(id)
    if mio and mio >= r then
      paso("Abre " .. prof .. " (libro de hechizos, pestaña de profesiones).", "Open " .. prof .. " (spellbook, professions tab).")
      paso("Busca " .. x.n .. " en la lista.", "Find " .. x.n .. " in the list.")
      if rec then
        local mats, todo = textoMats(rec.mats)
        paso("Materiales: " .. mats .. ".", "Materials: " .. mats .. ".")
        if not todo then paso("Lo que te falte: recógelo o cómpralo en la casa de subastas.", "What you are missing: gather it or buy it at the Auction House."); botonSubasta() end
      end
      if x.fab[3] and x.fab[3]:find("patron", 1, true) then paso("Si no sale en la lista, te falta la receta: no la enseña el entrenador.", "If it is not in the list, you are missing the recipe: the trainer does not teach it.") end
      paso("Pulsa Crear.", "Press Create.")
    else
      if mio then
        paso("Te falta " .. prof .. " " .. r .. " (tienes " .. mio .. "). Sube la profesión y entrena el rango siguiente.", "You need " .. prof .. " " .. r .. " (you have " .. mio .. "). Level the profession and train the next rank.")
        local e = entrenadorDe(prof, r)
        if e then botones[#botones + 1] = { L("Llévame al entrenador de ", "Take me to the ") .. prof .. L("", " trainer"), function() return irEntrenador(e, prof) end } end
      else
        paso("Se fabrica con " .. prof .. " " .. r .. ". No tienes la profesión: lo más rápido es comprarlo.", "It is crafted with " .. prof .. " " .. r .. ". You do not have the profession: the fastest way is to buy it.")
      end
      if rec then paso("Materiales: " .. (textoMats(rec.mats)) .. ".", "Materials: " .. (textoMats(rec.mats)) .. ".") end
      paso("O cómpralo en la casa de subastas: habla con el subastador y busca " .. x.n .. ".", "Or buy it at the Auction House: talk to the auctioneer and search for " .. x.n .. ".")
      botonSubasta()
      if not mio then ruta = true end
    end
  else
    local o = x.otro or ""
    if o:find("mision", 1, true) then paso("Es recompensa de una misión.", "It is a quest reward.") end
    if o:find("botin", 1, true) then paso("Lo sueltan enemigos al morir (botín): no es de un sitio fijo.", "Enemies drop it (loot): it is not from one fixed place.") end
    paso("Lo más seguro: búscalo en la casa de subastas por su nombre, " .. x.n .. ".", "The surest way: search the Auction House for its name, " .. x.n .. ".")
    botonSubasta()
    ruta = true
  end
  local p = precio(id)
  if p and x.cl ~= "WARLOCK" then paso("Último precio que viste en la casa de subastas: " .. dinero(p) .. ".", "Last Auction House price you saw: " .. dinero(p) .. ".") end
  if not s and x.cl ~= "WARLOCK" then paso("Casa de subastas: " .. SIN_DATOS_ES .. ".", "Auction House: " .. SIN_DATOS_EN .. ".") end
  decir(x.n .. ": " .. x.es .. ". Te dejo los pasos en una ventana.", x.n .. ": " .. x.en .. ". The steps are in a window.")
  -- comprar = la unica forma para ti: la ruta a la casa de subastas arranca sola
  if ruta and s then WowF.irASubasta(x.n) end
  WowF.ventanaConsumible(id, x, pasos, botones)
  return true
end

-- ----- Casa de subastas mas cercana (wowF_Subastas_Datos.lua: Wowhead /forever, subastadores con su reaccion a cada faccion) -----
-- Vale la de tu faccion y la neutral (reaccion >= 0); la mas cercana por el costo de viaje desde donde estas
function WowF.subastaCercana()
  local col = miFac() == "H" and 6 or 7
  local lista = {}
  for _, a in ipairs(WowFSubastas or {}) do
    if (tonumber(a[col]) or -1) >= 0 then lista[#lista + 1] = { npc = a[2], id = a[1], m = a[3], x = a[4], y = a[5], neutral = (tonumber(a[col]) or 0) == 0 } end
  end
  if #lista == 0 then return nil end
  local c = lista[1]
  if WowF._bisMasCerca then local ok, r = pcall(WowF._bisMasCerca, lista); if ok and r then c = r end end
  return c
end
function WowF.irASubasta(objeto)
  local s = WowF.subastaCercana()
  if not s then decir("Casa de subastas: " .. SIN_DATOS_ES .. ".", "Auction House: " .. SIN_DATOS_EN .. "."); return false end
  local que = objeto and objeto ~= "" and objeto or L("lo que necesitas", "what you need")
  local guia = L("Habla con " .. s.npc .. ", pestaña Comprar: escribe " .. que .. ", ordena por precio por unidad y compra el más barato.",
    "Talk to " .. s.npc .. ", Buy tab: type " .. que .. ", sort by unit price and buy the cheapest.")
  if s.neutral then guia = guia .. " " .. L("(Casa neutral: comparte subastas con las dos facciones.)", "(Neutral house: shared with both factions.)") end
  decir("Casa de subastas más cercana: " .. s.npc .. ". Te llevo allí.", "Nearest Auction House: " .. s.npc .. ". Taking you there.")
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  local destino = { m = s.m, x = s.x, y = s.y, n = Y(s.npc), lugar = true, final = { titulo = s.npc, corto = s.npc, detalle = "",
    ventana = ORO .. L("Casa de subastas", "Auction House") .. "|r", texto = Y(L("Habla con ", "Talk to ") .. s.npc .. ": " .. que), llegada = Y(guia), npc = s.npc } }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = s.npc, sub = ORO .. Y(L("Casa de subastas: ", "Auction House: ") .. que) .. "|r" }) end
  if WowF.viajeA then local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }); if ok and hecho then return true end end
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    return (pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.m, s.x / 100, s.y / 100)) end))
  end
  return false
end

-- ----- Ventana "Como conseguirlo" (un consumible: pasos + botones) -----
local vCons
function WowF.ventanaConsumible(id, x, pasos, botones)
  local E = WowF.estilo
  if not vCons then
    local v = CreateFrame("Frame", "wowFConsumible", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    v:SetSize(400, 300); v:SetPoint("CENTER", 0, 60); v:SetFrameStrata("DIALOG")
    if E and E.marco then E.marco(v, "aviso") end
    v:EnableMouse(true); v:SetMovable(true); v:RegisterForDrag("LeftButton")
    v:SetScript("OnDragStart", v.StartMoving)
    v:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); if E and E.guardarPos then E.guardarPos(f, "consumiblePos") end end)
    if E and E.ponerPos then E.ponerPos(v, "consumiblePos") end
    if E and E.cabecera then v.cab = E.cabecera(v, 20); v.cab.titulo:SetText("FOREVER GUIDE") end
    local cerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
    if E and E.boton then E.boton(cerrar, "cuero", 11) end
    cerrar:SetSize(18, 18); cerrar:SetText("X"); cerrar:SetPoint("TOPRIGHT", -8, -8)
    cerrar:SetScript("OnClick", function() v:Hide() end)
    v.icono = v:CreateTexture(nil, "ARTWORK"); v.icono:SetSize(36, 36); v.icono:SetPoint("TOPLEFT", 16, -38)
    v.nombre = v:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if E and E.letra then E.letra(v.nombre, "marca", 15) end
    v.nombre:SetPoint("TOPLEFT", v.icono, "TOPRIGHT", 10, 0); v.nombre:SetPoint("RIGHT", -16, 0); v.nombre:SetJustifyH("LEFT")
    v.efecto = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if E and E.letra then E.letra(v.efecto, "cuerpo", 12) end
    v.efecto:SetPoint("TOPLEFT", v.nombre, "BOTTOMLEFT", 0, -3); v.efecto:SetPoint("RIGHT", -16, 0); v.efecto:SetJustifyH("LEFT")
    v.rotulo = v:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if E and E.letra then E.letra(v.rotulo, "marca", 12) end
    v.rotulo:SetPoint("TOPLEFT", 16, -86)
    v.texto = v:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if E and E.letra then E.letra(v.texto, "cuerpo", 13) end
    v.texto:SetPoint("TOPLEFT", v.rotulo, "BOTTOMLEFT", 0, -6); v.texto:SetPoint("RIGHT", -16, 0)
    v.texto:SetJustifyH("LEFT"); v.texto:SetJustifyV("TOP")
    if v.texto.SetSpacing then v.texto:SetSpacing(3) end
    v.botones = {}
    for i = 1, 2 do
      local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
      if E and E.boton then E.boton(b, i == 1 and "brasa" or "cuero", 12) end
      b:SetHeight(24)
      v.botones[i] = b
    end
    if WowF.registrarVentana then pcall(WowF.registrarVentana, v) end
    vCons = v
  end
  local v = vCons
  v.icono:SetTexture(icono(id))
  v.nombre:SetText((CALIDAD[x.q or 1] or "|cffffffff") .. x.n .. "|r")
  v.efecto:SetText(GRIS .. Y(L(x.es, x.en)) .. "|r")
  v.rotulo:SetText(ORO .. L("CÓMO CONSEGUIRLO", "HOW TO GET IT") .. "|r")
  local lineas = {}
  for i, s in ipairs(pasos) do lineas[#lineas + 1] = ORO .. i .. ".|r " .. s end
  v.texto:SetText(Y(table.concat(lineas, "\n")))
  local alto = (v.texto.GetStringHeight and tonumber(v.texto:GetStringHeight())) or (#pasos * 34)
  local y = 86 + 22 + alto + 14
  for i, b in ipairs(v.botones) do
    local d = botones[i]
    if d then
      b:SetText(Y(d[1]))
      b:SetScript("OnClick", function() pcall(d[2]) end)
      if E and E.botonAncho then pcall(E.botonAncho, b, false, 140) else b:SetWidth(220) end
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 16, -y)
      y = y + 30
      b:Show()
    else b:Hide() end
  end
  v:SetHeight(y + 12)
  v:Show()
  return v
end

-- ----- Seccion del Libro (pestana "BiS 30") -----
local TITULO = {
  vida = { "Poción de vida", "Health potion" }, mana = { "Poción de maná", "Mana potion" }, rabia = { "Poción de rabia", "Rage potion" },
  pocion30 = { "Poción de poder", "Power potion" }, elixir = { "Elixir", "Elixir" }, scroll = { "Scroll", "Scroll" },
  comidaBuff = { "Comida con Well Fed", "Well Fed food" }, bebida = { "Bebida", "Drink" }, comida = { "Comida", "Food" }, venda = { "Venda", "Bandage" },
  afilar = { "Piedra de afilar", "Sharpening stone" }, contrapeso = { "Contrapeso", "Weightstone" }, aceiteMana = { "Aceite de maná", "Mana oil" },
  aceiteHechizo = { "Aceite de hechizo", "Spell oil" }, piedraVida = { "Healthstone", "Healthstone" },
  descolorida = { "Poción descolorida", "Discolored potion" }, libre = { "Contra control", "Anti-control" }, detectar = { "Detectar invisibilidad", "Detect invisibility" },
  ron = { "Stamina", "Stamina" }, polvo = { "Control", "Control" }, energia = { "Energía", "Energy" }, resistencia = { "Resistencia", "Resistance" },
  velocidad = { "Velocidad", "Speed" }, invisible = { "Escapar", "Escape" }, proteccion = { "Protección", "Protection" }, explosivo = { "Explosivo", "Explosive" },
}
-- Raciales que cambian que consumible necesitas en PvP (foreverchanges.pro/racials; ninguna fuente de Forever da consumibles por raza)
local RAZA = {
  Human = { "Will to Survive quita los aturdimientos y Perception te deja ver el sigilo.", "Will to Survive removes stuns and Perception lets you see stealth." },
  Dwarf = { "Stoneform quita venenos y enfermedades: te sirve para limpiar lo que deja la poción Discolored.", "Stoneform removes poisons and diseases: it can clear what the Discolored potion leaves." },
  Gnome = { "Escape Artist te libra de raíces y frenos 3 s; la Free Action Potion sigue haciendo falta contra aturdimientos.", "Escape Artist frees you from roots and slows for 3 sec; you still need Free Action Potion against stuns." },
  NightElf = { "Rogues y Druids Night Elf son más difíciles de ver en sigilo.", "Night Elf Rogues and Druids are harder to see in stealth." },
  Orc = { "Hardiness: los aturdimientos te duran un 20 % menos.", "Hardiness: stuns last 20% less on you." },
  Scourge = { "Will of the Forsaken quita miedo, encanto y sueño (también el de Magic Dust).", "Will of the Forsaken removes fear, charm and sleep (also Magic Dust's)." },
  Troll = { "Rapid Regeneration cura el 50 % de tu vida en 6 s: es como una poción más.", "Rapid Regeneration heals 50% of your health over 6 sec: it works like one more potion." },
}
local function fila(f, item, D)
  local id = f.id or f.prox
  local x = D.lista[id]
  local t = TITULO[f.cat] or { f.cat, f.cat }
  local etiqueta = (f.reco and (VERDE .. L("RECOMENDADO: ", "RECOMMENDED: ")) or (CELESTE .. L(t[1], t[2]) .. ": ")) .. "|r"
  local nombre = (CALIDAD[x.q or 1] or "|cffffffff") .. x.n .. "|r"
  local sub = GRIS .. L(x.es, x.en) .. "|r"
  if x.nuevo then sub = sub .. " " .. MORADO .. L("(nuevo de Forever)", "(new in Forever)") .. "|r" end
  if f.porEs then sub = sub .. "\n" .. GRIS .. L(f.porEs, f.porEn) .. "|r" end
  if f.id then
    sub = sub .. "\n" .. comoSeConsigue(id, x)
  else
    sub = sub .. "\n" .. NARANJA .. L("Desde el nivel " .. x.rl .. ".", "From level " .. x.rl .. ".") .. "|r " .. comoSeConsigue(id, x)
  end
  if f.id and f.prox then
    local y = D.lista[f.prox]
    sub = sub .. "\n" .. ORO .. L("Al nivel " .. y.rl .. ": ", "At level " .. y.rl .. ": ") .. "|r" .. y.n .. GRIS .. " (" .. L(y.es, y.en) .. ")|r"
  end
  local acc = function() return WowF.irAConsumible(id) end
  item({ texto = Y(etiqueta .. nombre), sub = Y(sub), icono = icono(id), objeto = id, sangria = 20, chico = true, accion = acc })
end

function WowF.seccionConsumibles(p, cab, nota, item)
  local D = datos()
  cab(Y(ORO .. L("Consumibles: lo mejor para ti (PvE y PvP)", "Consumables: the best for you (PvE and PvP)") .. "|r"), nil, { clave = "bis-consumibles" })
  if not D then nota(Y(NARANJA .. L("Consumibles: " .. SIN_DATOS_ES .. ".", "Consumables: " .. SIN_DATOS_EN .. ".") .. "|r")); return end
  local r = WowF.consumiblesDe(p)
  nota(Y(GRIS .. L("Solo de WoW Forever, hasta el nivel " .. (D.tope or 30) .. ". Cambia con tu nivel, tu rama, tus profesiones y tu facción. Clic: te llevo al vendedor o a la casa de subastas, o te explico cómo fabricarlo.",
    "WoW Forever only, up to level " .. (D.tope or 30) .. ". It changes with your level, spec, professions and faction. Click: I take you to the vendor or the Auction House, or explain how to craft it.") .. "|r"))
  if r.reco then
    nota(Y(VERDE .. L("Lo que recomienda la guía de tu rama sale primero. Fuente: ", "What your spec's guide recommends comes first. Source: ") .. "|r" .. GRIS .. (r.reco.fuente or "") .. "|r"))
    if r.reco.nota then nota(Y(GRIS .. L(r.reco.nota, r.reco.notaEn) .. "|r")) end
  else
    nota(Y(NARANJA .. L("Guía de consumibles de tu rama: " .. SIN_DATOS_ES .. ". Mientras, se ordenan con las estadísticas de tu rama.",
      "Consumables guide for your spec: " .. SIN_DATOS_EN .. ". Meanwhile, they are sorted with your spec's stats.") .. "|r"))
  end
  cab(Y(VERDE .. "PvE|r " .. GRIS .. L("(subir, mazmorras)", "(leveling, dungeons)") .. "|r"), nil, { clave = "bis-consumibles-pve" })
  for _, f in ipairs(r.pve) do fila(f, item, D) end
  cab(Y(MORADO .. "PvP|r " .. GRIS .. L("(campos de batalla, mundo)", "(battlegrounds, world)") .. "|r"), nil, { clave = "bis-consumibles-pvp" })
  for _, f in ipairs(r.pvp) do fila(f, item, D) end
  nota(Y(NARANJA .. L("Ver Rogues en sigilo: ningún consumible de WoW Forever lo hace (Draught of Detect Lesser Invisibility detecta invisibilidad, no sigilo). Solo la racial Human Perception (foreverchanges) y el perk Legacy High Alert (cliente de WoW Forever).",
    "Seeing stealthed Rogues: no WoW Forever consumable does it (Draught of Detect Lesser Invisibility detects invisibility, not stealth). Only the Human racial Perception (foreverchanges) and the Legacy perk High Alert (WoW Forever client).") .. "|r"))
  if WowF.notaLegacySigilo and WowF.notaLegacySigilo() then nota(WowF.notaLegacySigilo()) end
  if WowF.notaLegacyConsumibles and WowF.notaLegacyConsumibles() then nota(WowF.notaLegacyConsumibles()) end
  local raza = RAZA[r.raza or ""]
  if raza then nota(Y(CELESTE .. L("Tu raza: ", "Your race: ") .. "|r" .. GRIS .. L(raza[1], raza[2]) .. " (foreverchanges.pro/racials)|r")) end
  if not rango("Engineering") then
    nota(Y(GRIS .. L("Engineering: las guías PvP de WoWForeverBuilds incluyen sus bombas y granadas; salen aquí si tienes la profesión.",
      "Engineering: the WoWForeverBuilds PvP guides include its bombs and grenades; they show up here if you have the profession.") .. "|r"))
  end
  if r.clase == "ROGUE" then
    nota(Y(GRIS .. L("Rogue: los venenos los haces tú (Instant Poison para subir; en PvP, Wound Poison, según Icy Veins).",
      "Rogue: you make poisons yourself (Instant Poison while leveling; in PvP, Wound Poison, per Icy Veins).") .. "|r"))
  end
  nota(Y(NARANJA .. L("Aún no hay Flasks en la beta: todos piden nivel 50 o más.", "No Flasks in the beta yet: they all require level 50 or higher.") .. "|r"))
  for _, g in ipairs(D.general or {}) do
    local x = D.lista[g.id]
    if x then nota(Y(GRIS .. x.n .. ": " .. L(g.es, g.en) .. (g.fuente ~= "" and (" (" .. g.fuente .. ")") or "") .. "|r")) end
  end
end

-- ===================== 11-oct: vista por tarjetas (Andy: "aquí se sigue viendo con el estilo viejo") =====================
-- WowF.vistaConsumibles(k, x0, y0, ancho, p, ctx) -> y final. k = WowF.vistaKit de la vista "BiS 30" (sub-pestana Consumibles).
-- Mismos datos, clics y avisos que WowF.seccionConsumibles (que sigue igual: el Libro la arma oculta y la leen las pruebas).
-- Arriba: tarjeta con rotulo, una linea de explicacion y la fuente corta (URLs en la ayuda y en "copiar"); conmutador PvE / PvP;
-- cada consumible = tarjeta (2 columnas) con icono grande, nombre, chips (RECOMENDADO, nivel, nuevo, te lo fabricas), efecto,
-- para que, como conseguirlo en lineas cortas y boton secundario que hace lo mismo que el clic de siempre (WowF.irAConsumible).
local SIN_DATOS_V = { "aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update" }
local modoV -- "pve" | "pvp" (se guarda en WowFExportarDB.consumiblesModo)
local function colorV(n) local c = (WowF.estilo and WowF.estilo.color) or {}; return c[n] end
local function anchoChip(txt) return #tostring(txt or "") * 6.5 + 18 end
-- Nombre corto de cada fuente (la URL completa va en la ayuda y en "copiar")
local function fuentesCortas(fuente)
  local nombres, urls, ya = {}, {}, {}
  for u in tostring(fuente or ""):gmatch("[^·]+") do
    u = u:match("^%s*(.-)%s*$")
    if u ~= "" then
      urls[#urls + 1] = u
      local dom = (u:match("^https?://([^/]+)") or u):gsub("^www%.", "")
      local n = (dom:find("foreverchanges", 1, true) and "foreverchanges") or (dom:find("icy%-veins") and "Icy Veins")
        or (dom:find("wowforeverbuilds", 1, true) and "WoWForeverBuilds") or (dom:find("wowhead", 1, true) and "Wowhead") or dom
      if not ya[n] then ya[n] = true; nombres[#nombres + 1] = n end
    end
  end
  return table.concat(nombres, " · "), table.concat(urls, "\n")
end
-- Como se consigue, en lineas cortas (el detalle completo va en la ayuda de la tarjeta)
local function comoCorto(id, x)
  local t, tuyo = {}, false
  if x.cl then
    if x.cl == "WARLOCK" then t[#t + 1] = { L("Lo crea un Warlock (Create Healthstone); si no eres Warlock, pídeselo a uno de tu grupo", "Made by a Warlock (Create Healthstone); if you are not one, ask one in your group") } end
    return t, false
  end
  if x.fab then
    local prof, r = x.fab[1], x.fab[2]
    local mio = rango(prof)
    local receta = x.fab[3] and x.fab[3]:find("patron", 1, true) and L(" · receta aparte", " · separate recipe") or ""
    if mio and mio >= r then
      tuyo = true
      t[#t + 1] = { L("Te lo fabricas tú · " .. prof .. " " .. r .. " (tienes " .. mio .. ")", "You make it · " .. prof .. " " .. r .. " (you have " .. mio .. ")") .. receta, "verde" }
    elseif mio then
      t[#t + 1] = { L("Fabricado · " .. prof .. " " .. r .. " (tienes " .. mio .. ")", "Crafted · " .. prof .. " " .. r .. " (you have " .. mio .. ")") .. receta }
    else
      t[#t + 1] = { L("Fabricado · " .. prof .. " " .. r .. " (personaje de nivel " .. nivelParaRango(r) .. "+)", "Crafted · " .. prof .. " " .. r .. " (level " .. nivelParaRango(r) .. "+ character)") .. receta }
    end
  end
  local vd = vendedores(x)
  if #vd > 0 then
    local v = vd[1]
    if WowF._bisMasCerca then local ok, c = pcall(WowF._bisMasCerca, vd); if ok and c then v = c end end
    t[#t + 1] = { L("Vendedor · " .. v.npc .. " (" .. (v.z or "?") .. ")", "Vendor · " .. v.npc .. " (" .. (v.z or "?") .. ")") .. (#vd > 1 and L(" y " .. (#vd - 1) .. " más", " and " .. (#vd - 1) .. " more") or "") }
  end
  if not x.fab and #vd == 0 and x.otro then
    local o = x.otro
    t[#t + 1] = { L("Se consigue de: " .. o:gsub("botin", "botín"):gsub("mision", "misión"), "You get it from: " .. o:gsub("botin", "loot"):gsub("mision", "quest")) }
  end
  if not tuyo and #vd == 0 then
    local pr = precio(id)
    t[#t + 1] = { pr and L("Casa de subastas · " .. dinero(pr) .. " (último precio que viste)", "Auction House · " .. dinero(pr) .. " (last price you saw)")
      or L("Casa de subastas · búscalo allí", "Auction House · look for it there") }
  end
  return t, tuyo
end
-- Ayuda completa de la tarjeta: todo lo que decia la fila vieja
local function ayudaConsumible(f, id, x, D)
  return function(tt)
    local s = (CALIDAD[x.q or 1] or "|cffffffff") .. x.n .. "|r\n" .. GRIS .. L(x.es, x.en) .. "|r"
    if x.nuevo then s = s .. " " .. MORADO .. L("(nuevo de Forever)", "(new in Forever)") .. "|r" end
    if f.porEs then s = s .. "\n" .. GRIS .. L(f.porEs, f.porEn) .. "|r" end
    if not f.id then s = s .. "\n" .. NARANJA .. L("Desde el nivel " .. (x.rl or "?") .. ".", "From level " .. (x.rl or "?") .. ".") .. "|r" end
    s = s .. "\n" .. comoSeConsigue(id, x)
    if f.id and f.prox and D.lista[f.prox] then
      local y = D.lista[f.prox]
      s = s .. "\n" .. ORO .. L("Al nivel " .. y.rl .. ": ", "At level " .. y.rl .. ": ") .. "|r" .. y.n .. GRIS .. " (" .. L(y.es, y.en) .. ")|r"
    end
    s = s .. "\n|cff66ccff" .. L("Clic: te llevo al vendedor o a la casa de subastas, o te explico cómo fabricarlo", "Click: I take you to the vendor or the Auction House, or explain how to craft it") .. "|r"
    tt:SetText(Y(s), 1, 1, 1, 1, true)
  end
end
-- Una tarjeta de consumible; devuelve la tarjeta y el y final
local function tarjetaConsumible(k, x0, y0, w, f, D)
  local id = f.id or f.prox
  local x = D.lista[id]
  if not x then return nil, y0 end
  local ya = f.id ~= nil
  local card = k:tarjeta(x0, y0, w, 10, f.reco and "recomendada" or nil, nil, nil, true)
  k:icono(x0 + 14, y0 + 14, 44, icono(id), ya and "verde" or "gris", not ya)
  local tx = x0 + 14 + 44 + 12
  local tw = x0 + w - 14 - tx
  local t = TITULO[f.cat] or { f.cat, f.cat }
  k:rotulo(tx, y0 + 14, L(t[1], t[2]), colorV("tenue"))
  if f.reco then k:chip(x0 + w - 14, y0 + 10, L("RECOMENDADO", "RECOMMENDED"), "verde", true) end
  local _, hn = k:texto(tx, y0 + 32, Y((CALIDAD[x.q or 1] or "|cffffffff") .. x.n .. "|r"), { tam = 15, peso = "negrita", ancho = tw })
  local y = y0 + 32 + (tonumber(hn) or 16) + 6
  -- Chips: nivel (verde = ya puedes, gris = aun no), nuevo de Forever, te lo fabricas tu
  local lineas, tuyo = comoCorto(id, x)
  local chips = { { ((x.rl or 0) > 1) and L("Desde nivel " .. x.rl, "From level " .. x.rl) or L("Sin nivel mínimo", "No level required"), ya and "verde" or "gris" } }
  if x.nuevo then chips[#chips + 1] = { L("Nuevo de Forever", "New in Forever"), "oro" } end
  if tuyo then chips[#chips + 1] = { L("Te lo fabricas tú", "You make it"), "verde" } end
  local cx = tx
  for _, c in ipairs(chips) do
    local aw = anchoChip(c[1])
    if cx > tx and cx + aw > tx + tw then cx = tx; y = y + 24 end
    local _, wc = k:chip(cx, y, c[1], c[2])
    cx = cx + (tonumber(wc) or aw) + 6
  end
  y = y + 20 + 8
  local _, he = k:texto(tx, y, Y(L(x.es, x.en)), { tam = 13, color = (WowF.vistaKit and WowF.vistaKit.CLARO) or colorV("texto"), ancho = tw })
  y = y + (tonumber(he) or 16) + 4
  if f.porEs then
    local _, hp = k:texto(tx, y, Y(L(f.porEs, f.porEn)), { tam = 12, color = colorV("tenue"), ancho = tw })
    y = y + (tonumber(hp) or 14) + 4
  end
  for _, ln in ipairs(lineas) do
    local _, hl = k:texto(tx, y, Y(ln[1]), { tam = 12, color = colorV(ln[2] or "tenue"), ancho = tw })
    y = y + (tonumber(hl) or 14) + 2
  end
  if f.id and f.prox and D.lista[f.prox] then
    local s = D.lista[f.prox]
    local _, hx = k:texto(tx, y + 2, Y(L("Al nivel " .. s.rl .. ": ", "At level " .. s.rl .. ": ") .. s.n), { tam = 12, color = colorV("oro"), ancho = tw })
    y = y + 2 + (tonumber(hx) or 14) + 2
  end
  y = math.max(y, y0 + 14 + 44) + 8
  local fn = function() return WowF.irAConsumible(id) end
  k:zona(x0, y0, w, y - y0, fn, ayudaConsumible(f, id, x, D))
  local txtB = (#vendedores(x) > 0) and L("Llévame ›", "Take me there ›") or L("Cómo conseguirlo ›", "How to get it ›")
  k:boton(tx, y, txtB, "secundario", true, fn)
  y = y + 28 + 14
  return card, y
end

function WowF.vistaConsumibles(k, x0, y0, ancho, p, ctx)
  ctx = ctx or {}
  local D = datos()
  local y = y0
  -- Cabecera
  local cab = k:tarjeta(x0, y, ancho, 10, "principal")
  local yy = y + 14
  k:rotulo(x0 + 16, yy, L("Consumibles para ti", "Consumables for you"))
  yy = yy + 14 + 8
  local _, ht = k:texto(x0 + 16, yy, L("Lo mejor para ti: PvE y PvP", "The best for you: PvE and PvP"), { tam = 20, letra = "marca", ancho = ancho - 32 })
  yy = yy + (tonumber(ht) or 22) + 6
  if not D then
    local _, h = k:texto(x0 + 16, yy, Y(L("Consumibles: " .. SIN_DATOS_V[1] .. ".", "Consumables: " .. SIN_DATOS_V[2] .. ".")), { tam = 13, color = colorV("oro"), ancho = ancho - 32 })
    yy = yy + (tonumber(h) or 16) + 14
    cab:SetHeight(yy - y); k:hasta(yy)
    return yy
  end
  local r = WowF.consumiblesDe(p)
  local _, he = k:texto(x0 + 16, yy, Y(L("Solo de WoW Forever, hasta el nivel " .. (D.tope or 30) .. ". Cambia con tu nivel, tu rama, tus profesiones y tu facción. Clic: te llevo al vendedor o a la casa de subastas, o te explico cómo fabricarlo.",
    "WoW Forever only, up to level " .. (D.tope or 30) .. ". It changes with your level, spec, professions and faction. Click: I take you to the vendor or the Auction House, or explain how to craft it.")),
    { tam = 13, color = colorV("tenue"), ancho = ancho - 32 })
  yy = yy + (tonumber(he) or 16) + 6
  if r.reco then
    if r.reco.nota then
      local _, hn = k:texto(x0 + 16, yy, Y(L(r.reco.nota, r.reco.notaEn)), { tam = 13, color = colorV("orocl") or colorV("oro"), ancho = ancho - 32 })
      yy = yy + (tonumber(hn) or 16) + 6
    end
    local cortos, urls = fuentesCortas(r.reco.fuente)
    local _, hf, wf = k:texto(x0 + 16, yy + 2, Y(L("Lo de la guía de tu rama sale primero · Fuente: ", "Your spec's guide comes first · Source: ") .. cortos),
      { tam = 12, color = colorV("tenue") })
    if urls ~= "" then
      k:boton(x0 + 16 + (tonumber(wf) or 300) + 10, yy, L("copiar", "copy"), "terciario", false, function()
        if WowF.mostrarCopiaMacro then WowF.mostrarCopiaMacro(L("Fuentes", "Sources"), urls) else print(Y(urls)) end
      end, { ayuda = urls })
      k:anotar(urls)
    end
    yy = yy + math.max(tonumber(hf) or 14, 18) + 6
  else
    local _, ha = k:texto(x0 + 16, yy, Y(L("Guía de consumibles de tu rama: " .. SIN_DATOS_V[1] .. ". Mientras, se ordenan con las estadísticas de tu rama.",
      "Consumables guide for your spec: " .. SIN_DATOS_V[2] .. ". Meanwhile, they are sorted with your spec's stats.")), { tam = 13, color = colorV("oro"), ancho = ancho - 32 })
    yy = yy + (tonumber(ha) or 16) + 6
  end
  yy = yy + 8
  cab:SetHeight(yy - y); k:hasta(yy)
  y = yy + 12
  -- Conmutador PvE / PvP
  -- 12-oct (auditoria): sin eleccion guardada, empieza en el modo de tu rotacion (PvE/PvP)
  if not modoV then
    local guardado = WowFExportarDB and WowFExportarDB.consumiblesModo
    if guardado ~= "pve" and guardado ~= "pvp" and WowF.modoRotacion then
      local okM, m = pcall(WowF.modoRotacion)
      if okM and m == "pvp" then guardado = "pvp" end
    end
    modoV = (guardado == "pvp") and "pvp" or "pve"
  end
  local ops = { { "pve", L("PvE · subir y mazmorras", "PvE · leveling and dungeons") .. " (" .. #r.pve .. ")" },
    { "pvp", L("PvP · campos de batalla y mundo", "PvP · battlegrounds and world") .. " (" .. #r.pvp .. ")" } }
  k:seg(x0, y, ops, modoV, function(c)
    modoV = c; if WowFExportarDB then WowFExportarDB.consumiblesModo = c end
    if ctx.redibujar then ctx.redibujar() end
  end)
  y = y + 28 + 12
  -- Tarjetas en rejilla de 2 columnas (1 si no cabe)
  local lista = r[modoV] or {}
  if #lista == 0 then
    local c = k:tarjeta(x0, y, ancho, 10)
    local _, h = k:texto(x0 + 16, y + 14, Y(L(SIN_DATOS_V[1], SIN_DATOS_V[2])), { tam = 13, color = colorV("tenue"), ancho = ancho - 32 })
    local fin = y + 14 + (tonumber(h) or 16) + 14
    c:SetHeight(fin - y); k:hasta(fin)
    y = fin + 12
  else
    local cols = (ancho >= 600) and 2 or 1
    local gap = 12
    local cw = math.floor((ancho - gap * (cols - 1)) / cols)
    local i = 1
    while i <= #lista do
      local fila, finFila = {}, y
      for c = 0, cols - 1 do
        local f = lista[i + c]
        if f then
          local card, fin = tarjetaConsumible(k, x0 + c * (cw + gap), y, cw, f, D)
          if card then fila[#fila + 1] = card end
          if fin > finFila then finFila = fin end
        end
      end
      for _, card in ipairs(fila) do card:SetHeight(finFila - y) end
      k:hasta(finFila)
      y = finFila + gap
      i = i + cols
    end
  end
  -- A tener en cuenta (avisos y notas de siempre)
  local notas = {}
  notas[#notas + 1] = { L("Ver Rogues en sigilo: ningún consumible de WoW Forever lo hace (Draught of Detect Lesser Invisibility detecta invisibilidad, no sigilo). Solo la racial Human Perception (foreverchanges) y el perk Legacy High Alert (cliente de WoW Forever).",
    "Seeing stealthed Rogues: no WoW Forever consumable does it (Draught of Detect Lesser Invisibility detects invisibility, not stealth). Only the Human racial Perception (foreverchanges) and the Legacy perk High Alert (WoW Forever client)."), "orocl" }
  if WowF.notaLegacySigilo and WowF.notaLegacySigilo() then notas[#notas + 1] = { WowF.notaLegacySigilo() } end
  if WowF.notaLegacyConsumibles and WowF.notaLegacyConsumibles() then notas[#notas + 1] = { WowF.notaLegacyConsumibles() } end
  local raza = RAZA[r.raza or ""]
  if raza then notas[#notas + 1] = { L("Tu raza: ", "Your race: ") .. L(raza[1], raza[2]) .. " (foreverchanges.pro/racials)" } end
  if not rango("Engineering") then
    notas[#notas + 1] = { L("Engineering: las guías PvP de WoWForeverBuilds incluyen sus bombas y granadas; salen aquí si tienes la profesión.",
      "Engineering: the WoWForeverBuilds PvP guides include its bombs and grenades; they show up here if you have the profession.") }
  end
  if r.clase == "ROGUE" then
    notas[#notas + 1] = { L("Rogue: los venenos los haces tú (Instant Poison para subir; en PvP, Wound Poison, según Icy Veins).",
      "Rogue: you make poisons yourself (Instant Poison while leveling; in PvP, Wound Poison, per Icy Veins).") }
  end
  notas[#notas + 1] = { L("Aún no hay Flasks en la beta: todos piden nivel 50 o más.", "No Flasks in the beta yet: they all require level 50 or higher.") }
  for _, g in ipairs(D.general or {}) do
    local x = D.lista[g.id]
    if x then notas[#notas + 1] = { x.n .. ": " .. L(g.es, g.en) .. (g.fuente ~= "" and (" (" .. g.fuente .. ")") or "") } end
  end
  local cn = k:tarjeta(x0, y, ancho, 10, "hundida")
  local ny = y + 14
  k:rotulo(x0 + 16, ny, L("A tener en cuenta", "Good to know"), colorV("oro"))
  ny = ny + 14 + 10
  for _, n in ipairs(notas) do
    local _, h = k:texto(x0 + 16, ny, Y(n[1]), { tam = 12, color = colorV(n[2] or "tenue"), ancho = ancho - 32 })
    ny = ny + (tonumber(h) or 14) + 6
  end
  ny = ny + 8
  cn:SetHeight(ny - y); k:hasta(ny)
  return ny
end

-- ----- /wowf consumibles -----
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(msg, ...)
    local c = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    if c == "consumibles" or c == "consumables" or c == "pociones" or c == "potions" then
      if WowF.abrirLibro then WowF.abrirLibro("BiS 30") else
        local r = WowF.consumiblesDe()
        if not r then decir(SIN_DATOS_ES .. ".", SIN_DATOS_EN .. ".") return end
        for _, f in ipairs(r.pve) do local x = WowFConsumibles.lista[f.id or f.prox]; print(Y("PvE: " .. x.n)) end
        for _, f in ipairs(r.pvp) do local x = WowFConsumibles.lista[f.id or f.prox]; print(Y("PvP: " .. x.n)) end
      end
      return
    end
    if ordenAnterior then return ordenAnterior(msg, ...) end
  end
end
