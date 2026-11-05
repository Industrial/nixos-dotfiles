-- 5-oct: pestana Equipo del Libro: por cada casilla, la SIGUIENTE mejora real segun los pesos de tu rama (WowF.compararPieza,
-- nunca el nivel de objeto) y de donde sale EXACTAMENTE:
--   * botin de mazmorra (p.botin: verificado en Wowhead /forever, solo mazmorras de tu faccion) con el jefe que la suelta;
--   * recompensa de mision (WowFDatos.recompensas / misionesEquipo, de herramientas/descargar-recompensas.mjs): quien da la mision
--     y donde (NPC con posicion en Wowhead). Solo misiones de tu faccion (bando desconocido = no entra), tu clase y tu raza.
-- Se recalcula con tu nivel, tu faccion y lo que llevas puesto (cache que se borra con PLAYER_LEVEL_UP, PLAYER_EQUIPMENT_CHANGED,
-- SKILL_LINES_CHANGED, BAG_UPDATE_DELAYED y QUEST_TURNED_IN; ademas la clave lleva nivel, faccion, clase y rama).
WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end


-- Casilla del personaje -> tipos de objeto (inv) que van ahi
local INV_DE_RANURA = { [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5, 20 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 }, [9] = { 9 },
  [10] = { 10 }, [11] = { 11 }, [12] = { 11 }, [13] = { 12 }, [14] = { 12 }, [15] = { 16 }, [16] = { 13, 21, 17 },
  [17] = { 14, 22, 23, 13 }, [18] = { 15, 25, 26, 28 } }
-- 7-oct: una One-Hand (13) va a la Main Hand o a la Off Hand segun el hueco que reemplaza (det.slot de compararPieza):
-- con dos armas (Rogue, Warrior Fury) asi sale la mejor para la otra mano
-- Grupo de comparacion: anillos (11/12) y trinkets (13/14) se comparan juntos (compararPieza usa la peor de las dos)
local GRUPO = { [12] = 11, [14] = 13 }
local DISTANCIA = { [15] = true, [25] = true, [26] = true }
local ID_CLASE = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11 }
local ID_RAZA = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Undead = 5, Tauren = 6, Gnome = 7, Troll = 8, Goblin = 9,
  BloodElf = 10, Draenei = 11 }

local function bitOn(mascara, n) return n and n > 0 and math.floor(mascara / 2 ^ (n - 1)) % 2 == 1 end
-- 5-oct (revision): valores del juego por WowF.llamar/WowF.numero (wowF_Exportar.lua): en la beta pueden ser secretos
local function llamarJuego(f, ...)
  if WowF.llamar then return WowF.llamar(f, ...) end
  if type(f) ~= "function" then return nil end
  local ok, v = pcall(f, ...)
  if ok and not (issecretvalue and issecretvalue(v)) then return v end
  return nil
end
local function nivelPj() return tonumber(llamarJuego(UnitLevel, "player") or "") or 1 end
local function claseId()
  local ok, _, token, id = pcall(UnitClass, "player")
  if ok and type(id) == "number" then return id end
  return ok and type(token) == "string" and ID_CLASE[token:upper()] or nil
end
local function razaId()
  local ok, _, archivo, id = pcall(UnitRace, "player")
  if ok and type(id) == "number" then return id end
  return ok and type(archivo) == "string" and ID_RAZA[archivo] or nil
end
local function hecha(qid)
  if WowF.misionHecha then return WowF.misionHecha(qid) end
  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
    local ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid); return ok and r == true
  end
  if type(IsQuestFlaggedCompleted) == "function" then local ok, r = pcall(IsQuestFlaggedCompleted, qid); return ok and r == true end
  return false
end
local function nombreObj(id)
  local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  return o and o[1] or ("#" .. tostring(id)), o and o[2] or 1, o and o[3] or ""
end

-- Puntuacion propia de una pieza (misma formula que wowF_Comparar): para ordenar y para "te dura hasta"
local function puntuar(c, pesos)
  if not pesos then return 0 end
  local p, l = 0, c.st or {}
  for i = 1, #l - 1, 2 do p = p + (pesos[l[i]] or 0) * l[i + 1] end
  if pesos.ar then p = p + (c.ar or 0) * pesos.ar end
  if (c.dps or 0) > 0 then p = p + c.dps * ((DISTANCIA[c.inv] and pesos.dpsDist or pesos.dps) or 0) end
  return p
end

-- Una mision se puede hacer: tu faccion (bando 1 Alliance, 2 Horde, 3 las dos; otro valor = no se sabe = no se recomienda),
-- tu clase y tu raza (mascaras de Wowhead; si no se sabe tu raza y la mision pide una, no se recomienda)
local function misionMia(q, fac, cid, rid)
  local lado = q[4]
  if not (lado == 3 or (lado == 1 and fac == 2) or (lado == 2 and fac == 1)) then return false end
  if (q[5] or 0) ~= 0 and not bitOn(q[5], cid) then return false end
  if (q[6] or 0) ~= 0 and not bitOn(q[6], rid) then return false end
  return true
end

-- Todas las piezas verificadas para tu personaje (de cualquier nivel): { id, inv, st, ar, dps, nivel, desde, tipo, ... }
local function candidatos(p)
  local lista = {}
  local fac = WowF.miFaccion and WowF.miFaccion() or 0
  -- 12-oct (auditoria: Mail a un Shaman de 16): solo lo que tu clase puede llevar antes del tope de la beta (tipo de arma o
  -- armadura de wowF_Valiosos.lua); "desde" sube al nivel en que tu clase lo aprende (Polearms al 20)
  local okN, miNivel = pcall(UnitLevel, "player")
  miNivel = (okN and not (issecretvalue and issecretvalue(miNivel)) and tonumber(miNivel)) or 1
  local function claseOk(id, inv, pide)
    if not WowF.usoDeClase then return true, 0 end
    local ok, sirve, desde = pcall(WowF.usoDeClase, { id = id, inv = inv, nivel = pide or 0 }, inv, miNivel)
    if not ok then return true, 0 end
    return sirve, desde or 0
  end
  -- Mazmorras de tu faccion (esMia) con botin verificado
  local vistos = {}
  for _, m in ipairs(WowF.mejorasDe("mazmorra") and WowFMazmorras or {}) do
    local mia = (WowF.esMia and WowF.esMia(m)) or (not WowF.esMia and (m.f == 0 or m.f == fac))
    local botin = m.i and p.botin and p.botin[m.i]
    if mia and botin then
      for _, o in ipairs(botin) do
        local clave = m.n .. ":" .. tostring(o.id)
        local vale, dClase = false, 0
        if o.inv and not vistos[clave] then vale, dClase = claseOk(o.id, o.inv, o.nivel) end
        if vale then
          vistos[clave] = true
          table.insert(lista, { id = o.id, inv = o.inv, st = o.st or {}, ar = o.ar or 0, dps = o.dps or 0, nivel = o.nivel or 0,
            desde = math.max(o.nivel or 0, m.d or 0, dClase), tipo = "mazmorra", m = m, jefe = o.jefe, esJefe = o.esJefe, j = o.j })
        end
      end
    end
  end
  -- Recompensas de mision de tu rama
  local D = WowFDatos
  local c = D and D.clases and p.clase and D.clases[p.clase]
  local r = c and c.ramas and c.ramas[p.indiceRama or 0]
  if r and r.recompensas and D.recompensas and D.misionesEquipo and WowF.mejorasDe("mision") then
    local cid, rid = claseId(), razaId()
    for _, id in ipairs(r.recompensas) do
      local o = D.recompensas[id]
      local vale, dClase = false, 0
      if o then vale, dClase = claseOk(id, o[1], o[4]) end
      if vale then
        for _, qid in ipairs(o[6] or {}) do
          local q = D.misionesEquipo[qid]
          -- 5-oct: y que la linea no pase por una zona de otra raza (Zephras Isle = solo Skyborne)
          if q and misionMia(q, fac, cid, rid) and not (WowF.lineaImposible and WowF.lineaImposible(q[14], q[8])) then
            table.insert(lista, { id = id, inv = o[1], ar = o[2] or 0, dps = o[3] or 0, nivel = o[4] or 0, st = o[5] or {},
              desde = math.max(o[4] or 0, q[3] or 0, dClase), tipo = "mision",
              mision = { id = qid, nombre = q[1], nivelMision = q[2] or 0, quien = q[7], m = q[8], x = q[9], y = q[10], zona = q[11] or "", elegir = q[12] == 1, objeto = q[13] == 1, cadena = q[14] } })
            break
          end
        end
      end
    end
  end
  return lista
end

-- Se puede conseguir AHORA (o en 2 niveles): mazmorra abierta, mision aun no hecha y no gris
local function ahora(c, nivel)
  if c.desde > nivel + 2 then return false end
  if c.desde > ((WowFDatos and WowFDatos.topeBeta) or 30) then return false end -- 7-oct: la beta no llega a ese nivel
  if c.tipo == "mazmorra" then return (c.m.h or 99) >= nivel end
  if hecha(c.mision.id) then return false end
  return (c.mision.nivelMision or 0) + 6 >= nivel
end

-- Quien da la mision: un NPC (su nombre) o un objeto, p. ej. un cartel de WANTED ("el objeto ...")
local function quienTxt(q) if q.objeto then return L("el objeto \"" .. q.quien .. "\"", "the object \"" .. q.quien .. "\"") end return q.quien end
WowF.equipoQuien = quienTxt

-- 5-oct (Andy: "si la pieza sale de una linea de misiones, que diga que es una linea, no una sola, y como empezarla"):
-- la mision de la pieza como linea (wowF_LineaMisiones). nil = no es linea o ya hiciste los pasos de antes.
local function lineaDe(c)
  if not c or c.tipo ~= "mision" or type(c.mision.cadena) ~= "table" or not WowF.lineaDeEquipo then return nil end
  return WowF.lineaDeEquipo(c.mision.id, nombreObj(c.id))
end
local function lineaPendiente(c)
  local q = lineaDe(c)
  local st = q and WowF.estadoLinea and WowF.estadoLinea(q)
  return (st and st.i) and q or nil, st
end
WowF.equipoLinea = lineaPendiente

-- 5-oct (Andy: "la gente cree que lo que le das no es lo mejor; que quede claro, en un color que destaque"):
-- lo que propone la guia es lo mejor que puedes conseguir AHORA por esa via, no lo mejor del juego.
local AMARILLO = "|cffffee00"
local ORO_F = "|cffffd100"
function WowF.avisoMejorEquipo(corto)
  if corto then
    return AMARILLO .. L("Es lo mejor que puedes conseguir AHORA, a tu nivel, con misiones y mazmorras verificadas. Puede haber algo mejor que cae de otros enemigos, en la casa de subastas o con misiones de mas nivel.",
      "It is the best you can get RIGHT NOW, at your level, from verified quests and dungeons. Something better may drop from other enemies, be on the auction house or come from higher-level quests.") .. "|r"
  end
  return AMARILLO .. L("OJO: esto es lo mejor que puedes conseguir AHORA, con tu nivel y tu rama, haciendo misiones (o lineas de misiones) disponibles y en mazmorras con botin verificado. No es lo mejor del juego: algo mejor puede caer de otros jefes o enemigos, estar en la casa de subastas o llegar con misiones de mas nivel. Se recalcula solo al subir de nivel.",
    "NOTE: this is the best you can get RIGHT NOW, for your level and spec, from available quests (or questlines) and dungeons with verified loot. It is not the best in the game: something better may drop from other bosses or enemies, be on the auction house or come from higher-level quests. It updates by itself when you level up.") .. "|r"
end
-- 9-oct (cero Classic): de donde sale la puntuacion. El ORDEN de estadisticas es el de Icy Veins para WoW Forever (web/reglas.js pesosFuente);
-- los numeros no los da ninguna guia de Forever. Balance y Restoration del Druid aun no tienen orden publicado.
function WowF.avisoPesos(p)
  p = p or {}
  local rama = tostring(p.ramaPesos or p.ramaNombre or "")
  if p.clase == "DRUID" and (rama:find("Balance") or rama:find("Restoration")) then
    return AMARILLO .. L("Tu rama aun no tiene orden de estadisticas de WoW Forever: la puntuacion es provisional y se actualizara.",
      "Your spec has no WoW Forever stat priority yet: the score is provisional and it will be updated.") .. "|r"
  end
  return AMARILLO .. L("La puntuacion sigue el orden de estadisticas de Icy Veins para WoW Forever; los valores exactos aun no estan confirmados.",
    "The score follows the Icy Veins stat priority for WoW Forever; the exact values are not confirmed yet.") .. "|r"
end
function WowF.avisoMejorFabricar()
  return AMARILLO .. L("OJO: esto es lo mejor que puedes fabricarte ahora, con tu nivel, tu rama y el rango de tu profesion. No es lo mejor del juego: puede haber algo mejor en misiones, mazmorras o la casa de subastas, y al subir el rango salen piezas nuevas (mira \"Proximas al subir\").",
    "NOTE: this is the best you can craft right now, for your level, spec and profession skill. It is not the best in the game: something better may come from quests, dungeons or the auction house, and new pieces unlock as your skill goes up (see \"Next as you level up\").") .. "|r"
end

-- 8-oct (4.11, pedido de pala1 en CurseForge: "filter gear upgrades... unchecking dungeon upgrades"): de donde se muestran mejoras.
-- tipo = "mision" | "mazmorra" | "fabricar"; casillas en Ajustes (WowFExportarDB.mejorasMision/Mazmorra/Fabricar, encendidas por defecto)
local CLAVE_FILTRO = { mision = "mejorasMision", mazmorra = "mejorasMazmorra", fabricar = "mejorasFabricar" }
-- Solo la casilla de Ajustes (sin el estilo de juego): la usan los chips "Mostrar mejoras de" de Equipo
function WowF.mejorasDeAjuste(tipo)
  local k = CLAVE_FILTRO[tipo]
  return not (k and type(WowFExportarDB) == "table" and WowFExportarDB[k] == false)
end
-- 11-oct (ideas de GearQuest): estilo de juego en Equipo. todo | sinMazmorras | soloMazmorras | yaPuedo | comprar
-- (WowFExportarDB.estiloEquipo). Se suma a las casillas de Ajustes: un origen apagado en cualquiera de los dos no sale.
-- 11-oct (Andy: "muy confuso"): Equipo muestra una sola fila Todo/Misiones/Mazmorras/Fabricar/Comprar (soloMisiones, soloFabricar);
-- sinMazmorras y yaPuedo se aceptan aun (guardados viejos y pruebas)
local ESTILOS = { todo = true, sinMazmorras = true, soloMazmorras = true, yaPuedo = true, comprar = true, soloMisiones = true, soloFabricar = true }
WowF.ESTILOS_EQUIPO = { "todo", "sinMazmorras", "soloMazmorras", "yaPuedo", "comprar", "soloMisiones", "soloFabricar" }
function WowF.estiloEquipo()
  local e = type(WowFExportarDB) == "table" and WowFExportarDB.estiloEquipo
  return ESTILOS[e or ""] and e or "todo"
end
function WowF.ponerEstiloEquipo(e)
  if not ESTILOS[e or ""] or type(WowFExportarDB) ~= "table" then return false end
  WowFExportarDB.estiloEquipo = e
  if WowF.equipoGuiaLimpiar then WowF.equipoGuiaLimpiar() end
  return true
end
local OCULTA_ESTILO = {
  sinMazmorras = { mazmorra = true },
  soloMazmorras = { mision = true, fabricar = true },
  soloMisiones = { mazmorra = true, fabricar = true },
  soloFabricar = { mision = true, mazmorra = true },
  comprar = { mision = true, mazmorra = true, fabricar = true },
}
function WowF.mejorasDe(tipo)
  if not WowF.mejorasDeAjuste(tipo) then return false end
  local o = OCULTA_ESTILO[WowF.estiloEquipo()]
  return not (o and o[tipo])
end
-- Linea para la pestana Equipo cuando hay algun origen apagado (nil = todo encendido)
local function textoEstilo(e)
  if e == "sinMazmorras" then return L("Estilo: sin mazmorras (solo misiones y fabricar).", "Style: no dungeons (quests and crafting only).") end
  if e == "soloMazmorras" then return L("Estilo: solo mazmorras.", "Style: dungeons only.") end
  if e == "soloMisiones" then return L("Estilo: solo misiones.", "Style: quests only.") end
  if e == "soloFabricar" then return L("Estilo: solo lo que te fabricas.", "Style: crafted only.") end
  if e == "yaPuedo" then return L("Estilo: solo lo que ya puedes conseguir a tu nivel.", "Style: only what you can already get at your level.") end
  if e == "comprar" then return L("Estilo: comprar (vendedores de la guia BiS de tu faccion). Casa de subastas: aun no hay datos de WoW Forever; pendiente de actualizar.",
    "Style: buy (vendors from the BiS guide for your faction). Auction house: no WoW Forever data yet; pending update.") end
  return nil
end
WowF.textoEstiloEquipo = textoEstilo
function WowF.avisoFiltroMejoras()
  local e = textoEstilo(WowF.estiloEquipo())
  if e then return ORO_F .. e .. "|r" end
  local mis, maz = WowF.mejorasDe("mision"), WowF.mejorasDe("mazmorra")
  if mis and maz then return nil end
  if not mis and not maz then
    return ORO_F .. L("Tienes apagadas las mejoras de misiones y de mazmorras: no queda nada que mostrar aqui. Enciendelas en Ajustes (/wowf ajustes).",
      "Quest and dungeon upgrades are both turned off: there is nothing left to show here. Turn them on in Settings (/wowf settings).") .. "|r"
  end
  return ORO_F .. (mis and L("Filtro: solo mejoras de misiones (las de mazmorras estan apagadas en Ajustes).", "Filter: quest upgrades only (dungeon upgrades are turned off in Settings).")
    or L("Filtro: solo mejoras de mazmorras (las de misiones estan apagadas en Ajustes).", "Filter: dungeon upgrades only (quest upgrades are turned off in Settings).")) .. "|r"
end

-- De donde sale, en una frase
function WowF.equipoFuente(c)
  if not c then return "" end
  if c.tipo == "mazmorra" then
    local quien
    if c.esJefe and c.jefe then quien = L("jefe ", "boss ") .. c.jefe
    elseif c.j == "cualquier enemigo de la mazmorra" then quien = L("cualquier enemigo", "any enemy")
    else quien = L("jefe sin confirmar", "boss not confirmed") end
    return L("Mazmorra ", "Dungeon ") .. c.m.n .. " (" .. quien .. ")"
  end
  local q = c.mision
  return L("Mision \"" .. q.nombre .. "\" de " .. quienTxt(q) .. " (" .. q.zona .. ")", "Quest \"" .. q.nombre .. "\" from " .. quienTxt(q) .. " (" .. q.zona .. ")")
    .. (q.elegir and L(", la eliges como recompensa", ", pick it as the reward") or "")
    .. (function() local lq = lineaDe(c); local r = lq and WowF.lineaResumen and WowF.lineaResumen(lq) or ""; return r ~= "" and ("  " .. r) or "" end)()
end

-- Llevame: ruta a la mazmorra o a quien da la mision
function WowF.irARecompensa(c)
  if not c then return false end
  WowF._ultimaRutaEquipo = c
  if c.tipo == "mazmorra" then
    if WowF.irAMazmorra then WowF.irAMazmorra(c.m) end
    return true
  end
  local q = c.mision
  local item = nombreObj(c.id)
  -- Linea de misiones: la cuenta entera y te lleva al paso que toca
  local lq = lineaPendiente(c)
  if lq and WowF.irALinea then
    print(Y("|cff33ccffForever Guide|r: " .. L("para conseguir " .. item .. " hay que hacer una LINEA de misiones: varias misiones seguidas, cada una abre la siguiente. Te guio paso a paso (ventana con la linea y ruta en el mapa):",
      "to get " .. item .. " you must do a QUESTLINE: several quests in a row, each one unlocks the next. I will guide you step by step (questline window and route on the map):")))
    if WowF.irALinea(lq) then return true end
  end
  print(Y("|cff33ccffForever Guide|r: " .. L("para conseguir " .. item .. ", acepta la mision \"" .. q.nombre .. "\" de " .. quienTxt(q) .. " (" .. q.zona .. ") y completala"
      .. (q.elegir and "; al entregarla, elige " .. item .. "." or "; te la dan al entregarla."),
    "to get " .. item .. ", accept the quest \"" .. q.nombre .. "\" from " .. quienTxt(q) .. " (" .. q.zona .. ") and complete it"
      .. (q.elegir and "; when you turn it in, pick " .. item .. "." or "; you get it when you turn it in."))))
  local destino = { m = q.m, x = q.x, y = q.y, n = Y(q.quien .. " (" .. L("mision: ", "quest: ") .. q.nombre .. ")") }
  -- 6-oct: al llegar, "habla con X y acepta Y" (no "la entrada de") y X marcado sobre su nombre hasta que la aceptas
  local hablar = q.objeto and L("Busca " .. quienTxt(q) .. " y acepta ", "Find " .. quienTxt(q) .. " and accept ") or L("Habla con ", "Talk to ") .. q.quien .. L(" y acepta ", " and accept ")
  destino.final = { texto = Y(hablar .. "\"" .. q.nombre .. "\""), titulo = q.quien, corto = q.quien,
    detalle = Y(L("Te da " .. item .. ".", "It gives you " .. item .. ".")), llegada = Y(hablar .. "\"" .. q.nombre .. "\"."), npc = not q.objeto and q.quien or nil, qid = q.id }
  if not q.objeto and WowF.marcarNPC then pcall(WowF.marcarNPC, { n = q.quien, qid = q.id, sub = "|cffffd100" .. Y(L("Equipo: ", "Gear: ") .. item) .. "|r" }) end
  if WowF.viajeA and WowF.viajeA(destino, { dibujar = true }) then return true end
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(q.m, q.x / 100, q.y / 100)); if C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end end)
  end
  print(Y("|cff33ccffForever Guide|r: " .. L("alfiler en " .. quienTxt(q) .. " (" .. q.zona .. ").", "pin on " .. quienTxt(q) .. " (" .. q.zona .. ").")))
  return true
end

local cache, claveCache = nil, nil
local function firmaEquipo()
  local t = {}
  for s = 1, 18 do
    local ok, l = pcall(GetInventoryItemLink or function() end, "player", s)
    t[#t + 1] = (ok and type(l) == "string" and not (issecretvalue and issecretvalue(l))) and l or "-"
  end
  return table.concat(t, ",")
end

-- Resultado: { ranuras = { [slot] = c (con c.cuanto, c.texto, c.hasta, c.puntos) }, mazmorra = { m, n, piezas }, total, nivel }
function WowF.equipoGuia(p)
  if not p or not p.pesos then return nil end
  local nivel = nivelPj()
  local fac = WowF.miFaccion and WowF.miFaccion() or 0
  local clave = table.concat({ nivel, fac, tostring(p.clase), tostring(p.indiceRama), tostring(p.ramaPesos), firmaEquipo(), tostring(WowF.mejorasDe("mision")), tostring(WowF.mejorasDe("mazmorra")), WowF.estiloEquipo(), (WowF.enIngles and WowF.enIngles()) and "en" or "es" }, "|")
  if cache and claveCache == clave and cache.p == p then return cache end
  local todos = candidatos(p)
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  for _, c in ipairs(todos) do c.puntos = puntuar(c, p.pesos) end
  -- Mejor pieza por grupo de ranuras (comparada con lo que llevas)
  local porGrupo, buenas = {}, {}
  for _, c in ipairs(todos) do
    if c.puntos > 0 and ahora(c, nivel) and not (WowF.estiloEquipo() == "yaPuedo" and (c.desde or 0) > nivel) then
      local okCmp, sirve, texto, segura, cuanto, det = pcall(WowF.compararPieza, c, p) -- 12-oct: una pieza rara no tumba la pestana
      if not okCmp then sirve = false end
      -- 7-oct: la mejora pequena (det.dudosa: pierdes algo que cuenta) tambien sale, en dorado, pero siempre por detras de una mejora segura
      local dudosa = sirve and texto and not segura and type(det) == "table" and det.dudosa and not c.incierto
      if sirve and texto and (segura or dudosa) then
        local x = {}
        for k, v in pairs(c) do x[k] = v end
        x.texto, x.cuanto, x.vacia = texto, cuanto, cuanto == nil
        x.orden = cuanto or (1000 + x.puntos)
        if dudosa then x.dudosa = true; x.orden = (cuanto or 0) - 1000 end
        x.porqueCorto = WowF.porQueMejora and WowF.porQueMejora(det) or nil
        x.slot = type(det) == "table" and det.slot or nil
        table.insert(buenas, x)
      end
    end
  end
  local resultado = { ranuras = {}, nivel = nivel, total = 0 }
  local function mejorPara(invs, excluir, s)
    local mejor
    for _, x in ipairs(buenas) do
      local vale = false
      for _, i in ipairs(invs) do if x.inv == i then vale = true end end
      if x.inv == 13 and ((s == 17 and x.slot ~= 17) or (s == 16 and x.slot == 17)) then vale = false end
      if vale and x.id ~= excluir and (not mejor or x.orden > mejor.orden or (x.orden == mejor.orden and x.desde < mejor.desde)) then mejor = x end
    end
    return mejor
  end
  for s, invs in pairs(INV_DE_RANURA) do
    if not GRUPO[s] then
      local x = mejorPara(invs, nil, s)
      if x then resultado.ranuras[s] = x end
    end
  end
  -- Anillos y trinkets: la mejora va a la casilla vacia (o a la primera); si las dos estan vacias, la segunda mejor en la otra
  for _, par in ipairs({ { 11, 12 }, { 13, 14 } }) do
    local x = resultado.ranuras[par[1]]
    if x then
      local vacia1 = not llamarJuego(GetInventoryItemLink, "player", par[1])
      local vacia2 = not llamarJuego(GetInventoryItemLink, "player", par[2])
      if vacia2 and not vacia1 then resultado.ranuras[par[1]] = nil; resultado.ranuras[par[2]] = x
      elseif vacia1 and vacia2 then resultado.ranuras[par[2]] = mejorPara(INV_DE_RANURA[par[1]], x.id) end
    end
  end
  -- Con un arma de dos manos recomendada no se recomienda Off Hand
  if resultado.ranuras[16] and resultado.ranuras[16].inv == 17 then resultado.ranuras[17] = nil end
  -- 12-oct (Andy: "antes la guia mostraba varias opciones por origen"): las OTRAS mejoras verificadas de cada hueco con mejora
  -- (mismas reglas que mejorPara, sin la elegida ni la del otro anillo/trinket), de mejor a peor. Salen de "buenas", asi que
  -- respetan los filtros de Ajustes y el estilo de Equipo. Un hueco sin mejora elegida no lleva otras (en anillos y trinkets la
  -- mejora va a la casilla que toca). resultado.otras[slot] = { x, ... } (mismo formato que resultado.ranuras[slot]).
  resultado.otras = {}
  do
    local PAR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
    for s, invs in pairs(INV_DE_RANURA) do
      local elegida = resultado.ranuras[s]
      local l, visto = {}, {}
      if elegida then
        local otraId = PAR[s] and resultado.ranuras[PAR[s]] and resultado.ranuras[PAR[s]].id
        for _, x in ipairs(buenas) do
          local vale = false
          for _, i in ipairs(invs) do if x.inv == i then vale = true end end
          if x.inv == 13 and ((s == 17 and x.slot ~= 17) or (s == 16 and x.slot == 17)) then vale = false end
          local origen = (x.tipo == "mazmorra") and ("m:" .. tostring(x.m and x.m.n)) or ("q:" .. tostring(x.mision and x.mision.id))
          local cv = tostring(x.id) .. "|" .. origen
          if vale and x ~= elegida and not (x.id == elegida.id and x.tipo == elegida.tipo) and x.id ~= otraId and not visto[cv] then
            visto[cv] = true
            l[#l + 1] = x
          end
        end
        -- 12-oct (b) (Andy: "botas de mazmorra peores pero que se pueden conseguir"): ademas de lo de AHORA (nivel + 2), lo que
        -- llega en pocos niveles (hasta nivel + 5, nunca por encima del tope de la beta), con las mismas reglas: tu faccion, tu
        -- clase, mazmorra que aun no se te queda baja, mision no hecha ni gris, y que mejore lo que llevas (o la ranura vacia).
        -- x.futura = aun no la puedes conseguir (pide "desde nivel N"). El estilo "yaPuedo" no las muestra.
        if WowF.estiloEquipo() ~= "yaPuedo" then
          for _, c in ipairs(todos) do
            local vale = false
            for _, i in ipairs(invs) do if c.inv == i then vale = true end end
            local origen = (c.tipo == "mazmorra") and ("m:" .. tostring(c.m and c.m.n)) or ("q:" .. tostring(c.mision and c.mision.id))
            local cv = tostring(c.id) .. "|" .. origen
            if vale and not visto[cv] and c.puntos > 0 and c.id ~= elegida.id and c.id ~= otraId and not ahora(c, nivel)
              and (c.desde or 0) <= nivel + 5 and (c.desde or 0) <= tope
              and (c.tipo ~= "mazmorra" or (c.m.h or 99) >= nivel)
              and (c.tipo ~= "mision" or (not hecha(c.mision.id) and (c.mision.nivelMision or 0) + 6 >= nivel)) then
              local okCmp, sirve, texto, segura, cuanto, det = pcall(WowF.compararPieza, c, p) -- 12-oct: una pieza rara no tumba la pestana
              if not okCmp then sirve = false end
              local dudosa = sirve and texto and not segura and type(det) == "table" and det.dudosa and not c.incierto
              local slot = type(det) == "table" and det.slot or nil
              local okSlot = not (c.inv == 13 and ((s == 17 and slot ~= 17) or (s == 16 and slot == 17)))
              if okSlot and sirve and texto and (segura or dudosa) then
                local x = {}
                for k2, v in pairs(c) do x[k2] = v end
                x.texto, x.cuanto, x.vacia = texto, cuanto, cuanto == nil
                x.orden = cuanto or (1000 + x.puntos)
                if dudosa then x.dudosa = true; x.orden = (cuanto or 0) - 1000 end
                x.porqueCorto = WowF.porQueMejora and WowF.porQueMejora(det) or nil
                x.slot, x.futura = slot, true
                visto[cv] = true
                l[#l + 1] = x
              end
            end
          end
        end
        -- Comparacion corta con la elegida (la vista dice "un poco peor que X" / "peor que X" / "mejor que X, pero desde nivel N")
        for _, x in ipairs(l) do
          x.vsMejor = (elegida.puntos or 0) > 0 and ((x.puntos or 0) / elegida.puntos) or nil
          x.mejorId = elegida.id
        end
        -- Primero lo que puedes conseguir ya (de mejor a peor); luego lo de los proximos niveles
        table.sort(l, function(a, b)
          if (a.futura and true or false) ~= (b.futura and true or false) then return not a.futura end
          if a.orden ~= b.orden then return a.orden > b.orden end
          return (a.desde or 0) < (b.desde or 0)
        end)
      end
      resultado.otras[s] = l
    end
  end
  -- Te dura hasta: el primer nivel en que hay algo verificado al menos 15 % mejor para esa ranura
  for s, x in pairs(resultado.ranuras) do
    resultado.total = resultado.total + 1
    local invs, hasta = INV_DE_RANURA[s], nil
    for _, c in ipairs(todos) do
      local vale = false
      for _, i in ipairs(invs) do if c.inv == i then vale = true end end
      if vale and c.desde > math.max(x.desde, nivel) and c.desde <= tope and c.puntos >= x.puntos * 1.15 and (not hasta or c.desde < hasta)
        and (not WowF.vaEnRanuraRama or WowF.vaEnRanuraRama(c, p, s)) then hasta = c.desde end -- 12-oct: reglas de manos/daga/arma de tu rama
    end
    x.hasta = hasta
    x.tope = tope
  end
  -- 12-oct: lo mismo para las otras opciones (para que su tooltip diga cuanto duran, igual que la elegida)
  for s, l in pairs(resultado.otras) do
    local invs = INV_DE_RANURA[s]
    for _, x in ipairs(l) do
      local hasta
      for _, c in ipairs(todos) do
        local vale = false
        for _, i in ipairs(invs) do if c.inv == i then vale = true end end
        if vale and c.desde > math.max(x.desde, nivel) and c.desde <= tope and c.puntos >= x.puntos * 1.15 and (not hasta or c.desde < hasta)
        and (not WowF.vaEnRanuraRama or WowF.vaEnRanuraRama(c, p, s)) then hasta = c.desde end -- 12-oct: reglas de manos/daga/arma de tu rama
      end
      x.hasta, x.tope = hasta, tope
    end
  end
  -- La mejor mazmorra para tu equipo ahora: la abierta (tu faccion y tu nivel) con mas casillas que mejora
  local porMaz = {}
  for _, x in ipairs(buenas) do
    if x.tipo == "mazmorra" and not x.dudosa and (x.m.d or 0) <= nivel and nivel <= (x.m.h or 99) then
      local e = porMaz[x.m.n] or { m = x.m, grupos = {}, n = 0, suma = 0, piezas = {} }
      porMaz[x.m.n] = e
      local g = GRUPO[x.inv == 11 and 12 or (x.inv == 12 and 14 or 0)] or x.inv
      if not e.grupos[g] then e.grupos[g] = true; e.n = e.n + 1 end
      e.suma = e.suma + (x.cuanto or 1)
      table.insert(e.piezas, x)
    end
  end
  for _, e in pairs(porMaz) do
    if not resultado.mazmorra or e.n > resultado.mazmorra.n or (e.n == resultado.mazmorra.n and e.suma > resultado.mazmorra.suma) then resultado.mazmorra = e end
  end
  resultado.p = p
  resultado.todos = todos -- 11-oct: para WowF.puntuacionEquipo / WowF.rangoHueco
  cache, claveCache = resultado, clave
  return resultado
end

-- Textos de una mejora (para la casilla, la lista y el tooltip)
function WowF.equipoPorcentaje(x)
  if not x then return "" end
  if x.vacia then return L("ranura vacia", "empty slot") end
  return WowF.textoMejora((x.cuanto or 0) * 100)
end
function WowF.equipoDuracion(x, nivel)
  if not x then return "" end
  local desde = math.max(x.desde or 0, nivel or 0)
  if x.hasta then
    return L("te sirve del nivel " .. desde .. " al " .. x.hasta .. " (" .. (x.hasta - desde) .. (x.hasta - desde == 1 and " nivel" or " niveles") .. "): en el " .. x.hasta .. " hay algo 15 % mejor",
      "lasts from level " .. desde .. " to " .. x.hasta .. " (" .. (x.hasta - desde) .. (x.hasta - desde == 1 and " level" or " levels") .. "): at " .. x.hasta .. " there is something 15 % better")
  end
  return L("no hay nada verificado 15 % mejor hasta el nivel " .. (x.tope or 30), "nothing verified 15 % better up to level " .. (x.tope or 30))
end
function WowF.equipoAyuda(x, nivel)
  if not x then return "" end
  local n = nombreObj(x.id)
  local l = { "|cff33ff66" .. L("Siguiente mejora: ", "Next upgrade: ") .. n .. "  " .. WowF.equipoPorcentaje(x) .. "|r",
    x.texto or "",
    "|cffffd100" .. L("Sale de: ", "Source: ") .. "|r" .. WowF.equipoFuente(x) }
  if (x.nivel or 0) > (nivel or 0) then table.insert(l, L("Pide nivel ", "Requires level ") .. x.nivel) end
  table.insert(l, "|cff999999" .. WowF.equipoDuracion(x, nivel) .. "|r")
  table.insert(l, WowF.avisoMejorEquipo(true))
  -- Linea de misiones: que lo es, como empieza y que paso te toca
  local lq = lineaDe(x)
  if lq and WowF.lineaMisionTooltip then
    local hay = false
    for _, t in ipairs(WowF.lineaMisionTooltip(lq)) do table.insert(l, t[1]); hay = true end
    if hay and lineaPendiente(x) then return Y(table.concat(l, "\n")) end
  end
  table.insert(l, "|cff66ccff" .. (x.tipo == "mazmorra" and L("Clic: llevame a la mazmorra", "Click: take me to the dungeon")
    or L("Clic: llevame a quien da la mision", "Click: take me to the quest giver")) .. "|r")
  return Y(table.concat(l, "\n"))
end

-- 7-oct: "BiS 30: <pieza>" en cada hueco de Equipo (datos y clic de wowF_BiSGuia.lua: WowF.bisDe / WowF.irABiS).
-- Respeta faccion y rama igual que la ventana BiS (bisDe ya filtra la otra faccion). Sin datos para el hueco o la rama: lista vacia.
local BIS_HUECOS = { [1] = { "Head" }, [2] = { "Neck" }, [3] = { "Shoulder" }, [15] = { "Back" }, [5] = { "Chest" }, [9] = { "Wrist" },
  [10] = { "Hands" }, [6] = { "Waist" }, [7] = { "Legs" }, [8] = { "Feet" }, [11] = { "Finger 1" }, [12] = { "Finger 2" },
  [13] = { "Trinket 1" }, [14] = { "Trinket 2" }, [16] = { "Two-Hand", "Main Hand" }, [17] = { "Off Hand", "Shield", "Held In Off-hand" },
  [18] = { "Ranged", "Relic" } }
local CALIDAD_BIS = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
-- d = WowF.bisDe(p) ya calculado (opcional). Devuelve { { hueco, pz, llevas, texto, accion } } (vacia si no hay datos)
function WowF.equipoBiS(slot, p, d)
  local r = {}
  if not WowF.bisDe then return r end
  d = d or WowF.bisDe(p)
  if type(d) ~= "table" or not d.meta then return r end
  local quiero = {}
  for _, h in ipairs(BIS_HUECOS[slot] or {}) do quiero[h] = true end
  for _, f in ipairs(d.huecos or {}) do
    if quiero[f.hueco] and f.bis and (not WowF.bisEsMia or WowF.bisEsMia(f.bis)) then table.insert(r, { hueco = f.hueco, pz = f.bis, llevas = f.llevas, tienes = f.tienes }) end
  end
  for _, x in ipairs(r) do
    local pz = x.pz
    local sinConf = pz.ok == false or pz.bs == true
    x.texto = Y("|cffffd100BiS 30" .. (#r > 1 and (" (" .. x.hueco .. ")") or "") .. ":|r " .. (CALIDAD_BIS[pz.q or 1] or "|cffffffff") .. (pz.n or "?") .. "|r"
      .. (x.llevas and ("  |cff33ff66" .. L("(la llevas)", "(you wear it)") .. "|r") or "")
      -- 7-oct (ya lo tengo): la BiS que ya es tuya pero no esta puesta
      .. ((not x.llevas and x.tienes and x.tienes.donde == "bolsas") and ("  |cff33ff66" .. L("(la tienes en las bolsas)", "(in your bags)") .. "|r") or "")
      .. ((not x.llevas and x.tienes and x.tienes.donde == "banco") and ("  |cff33ff66" .. L("(la tienes en el banco)", "(in your bank)") .. "|r") or "")
      .. (sinConf and "  |cffff9933(?)|r" or ""))
    x.accion = function() return WowF.irABiS and WowF.irABiS(pz) end
    -- 8-oct (armas): la BiS de la guia no cumple la regla de arma de tu rama (velocidad o tipo): x.arma = por que la pone igual
    local s = (WowF.BIS_RANURAS and WowF.BIS_RANURAS[x.hueco] or {})[1]
    if WowF.ajusteArma and (s == 16 or s == 17 or s == 18) then
      local okA, aj = pcall(WowF.ajusteArma, pz, { clase = p and p.clase, ramaPesos = d.rama }, s)
      if okA and type(aj) == "table" and aj.motivo then
        x.arma = Y("|cffff9933" .. (aj.prohibido and L("Ojo: " .. aj.motivo .. ".", "Note: " .. aj.motivo .. ".")
          or L("La guía la pone de BiS aunque " .. aj.motivo .. ": suma más daño en total.", "The guide lists it as BiS although " .. aj.motivo .. ": it adds more damage overall.")) .. "|r")
      end
    end
  end
  return r
end

-- 12-oct ("Ver otras opciones" de Equipo, origen Comprar): piezas de VENDEDOR de la guia BiS / pre-BiS de tu faccion para un hueco
-- (bisDe ya quita la otra faccion; bisEsMia, tu clase). Sin las que ya llevas puestas. Devuelve { { pz, hueco } } (vacia sin datos).
function WowF.equipoVendedores(slot, p, d)
  local r = {}
  if not WowF.bisDe then return r end
  if d == nil then local ok, v = pcall(WowF.bisDe, p); d = ok and v or nil end
  if type(d) ~= "table" then return r end
  local quiero, vistos = {}, {}
  for _, h in ipairs(BIS_HUECOS[slot] or {}) do quiero[h] = true end
  for _, f in ipairs(d.huecos or {}) do
    if quiero[f.hueco] then
      local todas = {}
      if f.bis and not f.llevas then todas[#todas + 1] = f.bis end
      for _, pz in ipairs(f.prebis or {}) do if f.llevasPre ~= pz then todas[#todas + 1] = pz end end
      for _, pz in ipairs(todas) do
        if type(pz) == "table" and pz.t == "vendedor" and pz.id and not vistos[pz.id] and (not WowF.bisEsMia or WowF.bisEsMia(pz)) then
          vistos[pz.id] = true
          r[#r + 1] = { pz = pz, hueco = f.hueco }
        end
      end
    end
  end
  table.sort(r, function(a, b) return (a.pz.nv or 0) < (b.pz.nv or 0) end)
  return r
end

-- ===================== 11-oct (rediseño por tarjetas): puntuacion del equipo =====================
-- WowF.puntuacionEquipo(p) = lo que llevas puesto frente a lo mejor que puedes tener YA (misiones y mazmorras verificadas de
-- candidatosRef, mismos pesos de tu rama, SIN los filtros de la pestana ni de Ajustes). Formula del 13-oct: ver el bloque
-- "13-oct (Andy...)" mas abajo. total = media ponderada (0-100). La barra va en la escala de la BiS 30 (100 = lo mejor verificado
-- hasta el nivel 30 de la beta, o la pieza BiS si sabemos sus estadisticas): barra = lo tuyo, marcas.ahora = lo que puedes
-- tener ya, marcas.bis30 = 100. Sin pesos o sin ningun hueco comparable: { sinDatos = true, aviso } (total = nil).
local NOMBRE_HUECO = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
  [6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
  [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged" }
WowF.EQUIPO_NOMBRE_HUECO = NOMBRE_HUECO
local ORDEN_HUECOS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local function sinDatosTxt() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end

-- Tipos de objeto que cuentan para un hueco (Off Hand: la One-Hand solo si llevas dos armas o ya hay una One-Hand ahi)
local function invsDe(s, pzOH)
  local invs = INV_DE_RANURA[s] or {}
  if s ~= 17 then return invs end
  local doble = false
  if type(CanDualWield) == "function" then local ok, si = pcall(CanDualWield); doble = ok and si == true end
  if doble or (pzOH and pzOH.inv == 13) then return invs end
  local r = {}
  for _, i in ipairs(invs) do if i ~= 13 then r[#r + 1] = i end end
  return r
end
local function invEn(invs, inv) for _, i in ipairs(invs) do if i == inv then return true end end return false end
-- Lo puesto: pieza (o false si esta vacio; nil si no se pudo leer)
local function piezaPuesta(s)
  local link = llamarJuego(GetInventoryItemLink, "player", s)
  if type(link) ~= "string" or link == "" then return false end
  return WowF.piezaDeEnlace and WowF.piezaDeEnlace(link) or nil
end

-- 12-oct (Andy): la puntuacion es GENERAL. La referencia sale de TODO lo verificado (misiones y mazmorras),
-- sin el filtro de la pestana ni las casillas de Ajustes: el numero no cambia con Todo/Misiones/Fabricar/Comprar.
local cacheRef, claveRef = nil, nil
local function candidatosRef(p)
  local clave = table.concat({ nivelPj(), WowF.miFaccion and WowF.miFaccion() or 0, tostring(p.clase), tostring(p.indiceRama), tostring(p.ramaPesos), firmaEquipo(), (WowF.enIngles and WowF.enIngles()) and "en" or "es" }, "|")
  if cacheRef and claveRef == clave and cacheRef.p == p then return cacheRef.l end
  local orig = WowF.mejorasDe
  WowF.mejorasDe = function() return true end
  local ok, l = pcall(candidatos, p)
  WowF.mejorasDe = orig
  if not ok or type(l) ~= "table" then return nil end
  for _, c in ipairs(l) do c.puntos = puntuar(c, p.pesos) end
  cacheRef, claveRef = { p = p, l = l }, clave
  return l
end

-- 13-oct (Andy: "la puntuacion confunde"): todo el calculo en un bloque (tope de 200 locales) y una sola formula para
-- WowF.puntuacionEquipo, WowF.simularPieza, WowF.rangoHueco y WowF.estadoHueco.
--   valor del hueco = (puesto + B) / (mejor + B) x 100, con tope 100; hueco vacio = 0.
--   B (piso de cada pieza) = 0.05 x armadura (solo lo que falte para que la armadura pese 0.05 por punto; los tanques ya la
--   pesan 0.06-0.07) + 0.05 x tu nivel, si la pieza trae algo (estadisticas de tu rama o armadura).
--   Por que: muchas ramas no dan peso a la armadura, asi que una pieza blanca util valia 0 (igual que el hueco vacio). 0.05 por
--   punto de armadura = 20 de armadura valen como 1 punto de estadistica, poco al lado de las estadisticas reales; y 0.05 x nivel
--   (1 punto al nivel 20) es un colchon pequeno para que +1 frente a +2 no parezca la mitad. Es simetrico: la mejor pieza sigue
--   valiendo 100 y el hueco vacio sigue en 0.
--   Referencia (el 100) = solo lo que ya puedes usar: c.desde <= tu nivel y lo que pide ahora() (mazmorra de tu tramo, mision sin
--   hacer y no gris), lo que tu rama lleva en ese hueco (WowF.vaEnRanuraRama: unaManoEscudo sin Two-Hand...), SIEMPRE de
--   candidatosRef (sin filtros de la pestana ni de Ajustes). Si candidatosRef falla, no hay puntuacion (nunca la lista filtrada).
--   Peso: Main Hand 2; Off Hand 2 solo con dos armas (dobleEmpunadura); Ranged 2 solo Hunter; el resto 1.
--   Off Hand no cuenta si llevas un arma de dos manos o tu rama es de dos manos (dosManos).
do
  local PISO_ARMADURA, PISO_NIVEL = 0.05, 0.05
  local NOMBRE_STAT = { [3] = "Agility", [4] = "Strength", [5] = "Intellect", [6] = "Spirit", [7] = "Stamina",
    [12] = "Defense Rating", [13] = "Dodge Rating", [14] = "Parry Rating", [15] = "Block Rating", [31] = "Hit Rating",
    [32] = "Critical Strike Rating", [36] = "Haste Rating", [37] = "Expertise Rating", [38] = "Attack Power",
    [39] = "Ranged Attack Power", [40] = "Feral Attack Power", [41] = "Healing", [42] = "Spell Damage", [43] = "Mana per 5 sec.",
    [44] = "Armor Penetration", [45] = "Spell Power", [47] = "Spell Penetration", [48] = "Block Value",
    [142] = "Fire Damage", [143] = "Frost Damage", [144] = "Shadow Damage", [145] = "Arcane Damage", [146] = "Nature Damage", [147] = "Holy Damage" }
  -- Hueco(s) donde va cada tipo de objeto (simularPieza sin hueco)
  local HUECOS_DE_INV = { [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 },
    [9] = { 9 }, [10] = { 10 }, [16] = { 15 }, [11] = { 11, 12 }, [12] = { 13, 14 }, [13] = { 16 }, [21] = { 16 }, [17] = { 16 },
    [14] = { 17 }, [22] = { 17 }, [23] = { 17 }, [15] = { 18 }, [25] = { 18 }, [26] = { 18 }, [28] = { 18 } }

  local function pesoHueco(s, p)
    if s == 16 then return 2 end
    if s == 17 then return (p.manos == "dobleEmpunadura") and 2 or 1 end
    if s == 18 then return (p.clase == "HUNTER") and 2 or 1 end
    return 1
  end
  -- Pesos de tu rama con el dano de escuela (igual que wowF_Comparar)
  local function pesosRama(p)
    local ok, w = pcall(function() return WowF.pesosDe and WowF.pesosDe(p) end)
    return (ok and type(w) == "table") and w or p.pesos
  end
  -- Valor de una pieza en su hueco = puntos de tu rama + piso B (0 si no trae nada para ti)
  local function valorPieza(c, pw, nivel)
    if type(c) ~= "table" then return 0 end
    local pts = puntuar(c, pw)
    local ar = tonumber(c.ar) or 0
    if pts <= 0 and ar <= 0 then return 0 end
    local extra = math.max(0, PISO_ARMADURA - (tonumber(pw.ar) or 0))
    return math.max(0, pts) + extra * ar + PISO_NIVEL * nivel
  end
  -- Ya la puedes usar: nivel cumplido (sin el margen de +2 de la lista), lo de ahora() y tu rama la lleva en ese hueco
  local function usableYa(c, nivel, p, s)
    if (tonumber(c.desde) or 0) > nivel then return false end
    if not ahora(c, nivel) then return false end
    return WowF.vaEnRanuraRama == nil or WowF.vaEnRanuraRama(c, p, s) ~= false
  end
  local function deRama(c, p, s) return WowF.vaEnRanuraRama == nil or WowF.vaEnRanuraRama(c, p, s) ~= false end
  -- Candidatos de un hueco con su valor, de mayor a menor (un id una vez)
  local function listaHueco(todos, invs, filtro, pw, nivel)
    local l, visto = {}, {}
    for _, c in ipairs(todos) do
      if invEn(invs, c.inv) and not visto[c.id] then
        local ok, si = pcall(filtro, c)
        if ok and si then
          local v = valorPieza(c, pw, nivel)
          if v > 0 then visto[c.id] = true; l[#l + 1] = { c = c, v = v } end
        end
      end
    end
    table.sort(l, function(a, b) return a.v > b.v end)
    return l
  end
  local function nombrePieza(pz)
    if type(pz) ~= "table" then return nil end
    local n = type(pz.link) == "string" and pz.link:match("%[(.-)%]") or nil
    if (not n or n == "") and pz.id then n = nombreObj(pz.id) end
    return n
  end
  local function dosManosDe(p, puestas)
    return (type(puestas[16]) == "table" and puestas[16].inv == 17) or p.manos == "dosManos"
  end
  -- Color en los dos formatos: { r, g, b } por nombre y por posicion
  local function rgb(r, g, b) return { r = r, g = g, b = b, r, g, b } end
  local function palabraDe(v)
    if v <= 25 then return L("Flojo", "Weak"), rgb(0.78, 0.25, 0.2) end
    if v <= 50 then return L("Regular", "Fair"), rgb(0.9, 0.55, 0.2) end
    if v <= 75 then return L("Bueno", "Good"), rgb(0.9, 0.75, 0.25) end
    return L("Excelente", "Excellent"), rgb(0.49, 0.77, 0.35)
  end

  -- El calculo (cambio = { slot, pz } para simular una pieza en un hueco)
  local function calcular(p, nivel, cambio)
    local todos = candidatosRef(p)
    if type(todos) ~= "table" then return { sinDatos = true, aviso = sinDatosTxt() } end
    local pw = pesosRama(p)
    local tope = (WowFDatos and WowFDatos.topeBeta) or 30
    -- Valor de la pieza BiS de cada hueco, si esta entre las verificadas: sube la referencia de la BiS 30 (la barra)
    local porId = {}
    for _, c in ipairs(todos) do local v = valorPieza(c, pw, nivel); if v > (porId[c.id] or 0) then porId[c.id] = v end end
    local bisPts = {}
    local okB, d = pcall(function() return WowF.bisDe and WowF.bisDe(p) end)
    if okB and type(d) == "table" and WowF.equipoBiS then
      for s in pairs(NOMBRE_HUECO) do
        local okE, lista = pcall(WowF.equipoBiS, s, p, d)
        for _, x in ipairs(okE and type(lista) == "table" and lista or {}) do
          local v = x.pz and porId[x.pz.id]
          if v and v > (bisPts[s] or 0) then bisPts[s] = v end
        end
      end
    end
    local puestas = {}
    for _, s in ipairs(ORDEN_HUECOS) do puestas[s] = piezaPuesta(s) end
    if cambio then puestas[cambio.slot] = cambio.pz end
    local dosManos = dosManosDe(p, puestas)
    local res = { porHueco = {}, marcas = {}, nivel = nivel, incierto = {}, piezas = puestas, dosManos = dosManos }
    local function vPuesto(s)
      local pz = puestas[s]
      if pz == false then return 0 end
      if pz == nil then return nil end
      return valorPieza(pz, pw, nivel)
    end
    local function anotar(s, puesto, mejor, ref, peso, nota)
      if puesto == nil then table.insert(res.incierto, s); return end
      mejor = math.max(mejor or 0, puesto)
      ref = math.max(ref or 0, mejor)
      if mejor <= 0 then return end -- nada que comparar para tu rama en este hueco
      local valor = math.min(100, puesto / mejor * 100)
      local vacio = puestas[s] == false
      res.porHueco[s] = { valor = valor, puesto = puesto, mejor = mejor, ref = ref, vacio = vacio,
        nombre = NOMBRE_HUECO[s], peso = peso or pesoHueco(s, p), pieza = nombrePieza(puestas[s]), nota = nota,
        estado = vacio and "vacio" or ((valor >= 95) and "ok" or "mejora") }
    end
    -- 13-oct (Andy): en las ramas que no son de dos manos (dos armas, lanzador con Held In Off-hand, arma y escudo), las armas
    -- se comparan como BLOQUE: lo mejor = el maximo entre la mejor Two-Hand (cuenta por las dos manos) y la mejor pareja
    -- Main Hand + Off Hand (cada una con su peso). Antes el 100 de la Main Hand podia salir de una Two-Hand y la Off Hand se
    -- comparaba sola: quien llevaba una buena pareja sacaba un numero bajo, y quien llevaba una Two-Hand no veia que la pareja era mejor.
    --   Llevas Two-Hand: un hueco (Main Hand) con peso de las dos manos; su 100 = max(mejor Two-Hand, pareja / peso).
    --   Llevas pareja (o nada): si la Two-Hand gana, el 100 de cada mano sube en la misma proporcion (las dos quedan por debajo).
    -- La Off Hand solo suma su peso si hay algo para ti en ese hueco (o llevas algo).
    local function armas()
      local w16, w17 = pesoHueco(16, p), pesoHueco(17, p)
      local inv16, inv17 = invsDe(16), invsDe(17, puestas[17])
      local function partir(l) -- dos mejores no-Two-Hand (distintas), mejor Two-Hand
        local a, b, m2, i2 = nil, nil, 0, nil
        for _, x in ipairs(l) do
          if x.c.inv == 17 then if x.v > m2 then m2, i2 = x.v, x.c.id end
          elseif not a or x.v > a.v then b, a = a, x
          elseif (not b or x.v > b.v) and x.c.id ~= a.c.id then b = x end
        end
        return a, b, m2, i2
      end
      -- 13-oct (Andy, caso Rogue): la pareja de referencia son DOS armas distintas (antes salia Cruel Barb en las dos manos).
      -- Si la mejor de cada mano es la misma pieza, se toma la mejor combinacion: (1.a MH + 2.a OH) o (2.a MH + 1.a OH).
      local function pareja(l16, l17)
        local a, b, m2, i2 = partir(l16)
        local o1, o2
        for _, x in ipairs(l17) do
          if not o1 or x.v > o1.v then o2, o1 = o1, x
          elseif (not o2 or x.v > o2.v) and x.c.id ~= o1.c.id then o2 = x end
        end
        local mh, oh = a, o1
        if a and o1 and a.c.id == o1.c.id then
          local s1 = w16 * a.v + w17 * (o2 and o2.v or 0)
          local s2 = w16 * (b and b.v or 0) + w17 * o1.v
          if s1 >= s2 then mh, oh = a, o2 else mh, oh = b, o1 end
        end
        return mh and mh.v or 0, m2, oh and oh.v or 0, mh and mh.c.id or nil, i2, oh and oh.c.id or nil
      end
      local ya17 = listaHueco(todos, inv17, function(c) return usableYa(c, nivel, p, 17) end, pw, nivel)
      local al17 = listaHueco(todos, inv17, function(c) return (tonumber(c.desde) or 0) <= tope and deRama(c, p, 17) end, pw, nivel)
      local y1, y2, yOH, id1, id2, idOH = pareja(listaHueco(todos, inv16, function(c) return usableYa(c, nivel, p, 16) end, pw, nivel), ya17)
      local r1, r2, rOH = pareja(listaHueco(todos, inv16, function(c) return (tonumber(c.desde) or 0) <= tope and deRama(c, p, 16) end, pw, nivel), al17)
      -- Lo mejor que ya puedes usar en armas (para la vista y las pruebas): pareja y arma de dos manos
      res.armasRef = { mh = id1, oh = idOH, dosManos = id2, pesoMH = w16, pesoOH = w17 }
      r1 = math.max(r1, (bisPts[16] or 0)); rOH = math.max(rOH, bisPts[17] or 0)
      local v16, v17 = vPuesto(16), vPuesto(17)
      local ohCuenta = yOH > 0 or rOH > 0 or (v17 or 0) > 0
      local W = w16 + (ohCuenta and w17 or 0)
      local pz16 = puestas[16]
      if type(pz16) == "table" and pz16.inv == 17 then
        -- Llevas una Two-Hand: la pareja entra como alternativa (por cada mano, en promedio)
        local parYa = (w16 * y1 + (ohCuenta and w17 * yOH or 0)) / W
        local parRef = (w16 * r1 + (ohCuenta and w17 * rOH or 0)) / W
        local nota = (parYa > math.max(y2, v16 or 0) * 1.001) and "pareja" or nil
        anotar(16, v16, math.max(y2, parYa), math.max(r2, parRef, bisPts[16] or 0), W, nota)
        return
      end
      -- Llevas pareja (o nada): la Two-Hand cuenta por las dos manos
      local m1, mOH = math.max(y1, v16 or 0), ohCuenta and math.max(yOH, v17 or 0) or 0
      local par = w16 * m1 + (ohCuenta and w17 * mOH or 0)
      local f = (par > 0 and y2 * W > par * 1.001) and (y2 * W / par) or 1
      local q1, qOH = r1, rOH
      local parR = w16 * q1 + (ohCuenta and w17 * qOH or 0)
      local fR = (parR > 0 and r2 * W > parR) and (r2 * W / parR) or 1
      if par <= 0 then m1, f = y2, 1 end
      if parR <= 0 then q1, fR = r2, 1 end
      local nota = (f > 1) and "dosManos" or nil
      anotar(16, v16, m1 * f, q1 * fR, nil, nota)
      if ohCuenta then anotar(17, v17, mOH * f, qOH * fR, nil, nota) end
    end
    local bloqueArmas = p.manos ~= "dosManos"
    if bloqueArmas then
      if not pcall(armas) then bloqueArmas = false; res.porHueco[16], res.porHueco[17] = nil, nil end
    end
    res.armasBloque = bloqueArmas
    local hechos = {}
    if bloqueArmas then hechos[16], hechos[17] = true, true end
    for _, s in ipairs(ORDEN_HUECOS) do
      if not hechos[s] and not (s == 17 and dosManos) then
        local invs = invsDe(s, s == 17 and puestas[17] or nil)
        local ya = listaHueco(todos, invs, function(c) return usableYa(c, nivel, p, s) end, pw, nivel)
        local al30 = listaHueco(todos, invs, function(c) return (tonumber(c.desde) or 0) <= tope and deRama(c, p, s) end, pw, nivel)
        local par = (s == 11 and 12) or (s == 13 and 14) or nil
        if par then
          -- Anillos y trinkets: las dos mejores entre lo puesto y lo disponible; la mas alta para el hueco con mas valor
          hechos[par] = true
          local a, b = vPuesto(s), vPuesto(par)
          local function dosMejores(lista)
            local v = { a or 0, b or 0 }
            for i = 1, math.min(2, #lista) do v[#v + 1] = lista[i].v end
            table.sort(v, function(x, y) return x > y end)
            return v[1] or 0, v[2] or 0
          end
          local m1, m2 = dosMejores(ya)
          local r1, r2 = dosMejores(al30)
          local alto, bajo = s, par
          if (b or 0) > (a or 0) then alto, bajo = par, s end
          anotar(alto, vPuesto(alto), m1, math.max(r1, bisPts[alto] or 0))
          anotar(bajo, vPuesto(bajo), m2, math.max(r2, bisPts[bajo] or 0))
        else
          anotar(s, vPuesto(s), ya[1] and ya[1].v or 0, math.max(al30[1] and al30[1].v or 0, bisPts[s] or 0))
        end
      end
    end
    local sw, sv, sb, sa = 0, 0, 0, 0
    local det = {}
    for s, h in pairs(res.porHueco) do
      sw = sw + h.peso
      sv = sv + h.peso * h.valor
      sb = sb + h.peso * (h.puesto / h.ref * 100)
      sa = sa + h.peso * (h.mejor / h.ref * 100)
      det[#det + 1] = { slot = s, nombre = h.nombre, pieza = h.pieza, valor = math.floor(h.valor + 0.5), peso = h.peso, vacio = h.vacio, estado = h.estado }
    end
    table.sort(det, function(x, y)
      if x.valor ~= y.valor then return x.valor < y.valor end
      if x.peso ~= y.peso then return x.peso > y.peso end
      return x.slot < y.slot
    end)
    res.huecosDetalle, res.cuenta = det, #det
    if sw <= 0 then
      res.sinDatos, res.aviso = true, sinDatosTxt()
    else
      res.total = math.floor(sv / sw + 0.5)
      res.barra = math.floor(sb / sw + 0.5)
      res.marcas.ahora = math.floor(sa / sw + 0.5)
      res.marcas.bis30 = 100
      res.palabra, res.color = palabraDe(res.total)
    end
    -- El hueco que mas sube (el de menor valor; con empate, el de mas peso)
    local peor
    for s, h in pairs(res.porHueco) do
      if h.valor < 99.5 and (not peor or h.valor < res.porHueco[peor].valor or (h.valor == res.porHueco[peor].valor and h.peso > res.porHueco[peor].peso)) then peor = s end
    end
    res.peor = peor
    -- Huecos con mejora = valor < 95 (el mismo criterio que estado "mejora"/"vacio"; con < 95 nunca "Bien asi")
    res.faltan = 0
    for _, h in pairs(res.porHueco) do if h.valor < 95 then res.faltan = res.faltan + 1 end end
    res.conMejora = res.faltan
    return res
  end

  function WowF.puntuacionEquipo(p)
    p = p or (WowF.armarPlan and WowF.armarPlan())
    if type(p) ~= "table" or not p.pesos then return { sinDatos = true, aviso = sinDatosTxt() } end
    local g = WowF.equipoGuia(p)
    if type(g) ~= "table" then return { sinDatos = true, aviso = sinDatosTxt() } end
    if rawget(g, "_pu") then return g._pu end
    local ok, res = pcall(calcular, p, g.nivel or nivelPj(), nil)
    if not ok or type(res) ~= "table" then res = { sinDatos = true, aviso = sinDatosTxt() } end
    g._pu = res
    return res
  end

  -- Estado de un hueco para la vista: "ok" (Bien asi, valor >= 95), "mejora", "vacio" o nil (no cuenta / sin datos), y su valor
  function WowF.estadoHueco(slot, p)
    local pu = WowF.puntuacionEquipo(p)
    local h = type(pu) == "table" and pu.porHueco and pu.porHueco[slot]
    if not h then return nil end
    return h.estado, h.valor
  end

  -- Simula ponerte una pieza: item = itemID o enlace; slot opcional (anillos/trinkets: frente al mas flojo de los dos).
  -- { antes, despues, slot, hueco = { antes, despues }, stats = { { nombre, antes, despues } } } o nil si no se puede calcular.
  function WowF.simularPieza(p, item, slot)
    p = p or (WowF.armarPlan and WowF.armarPlan())
    if type(p) ~= "table" or not p.pesos then return nil end
    local pz
    local id = (type(item) == "number" and item) or (type(item) == "string" and tonumber(item:match("^%d+$") or item:match("item:(%d+)"))) or nil
    if type(item) == "string" and item:find("|H", 1, true) and WowF.piezaDeEnlace then pz = WowF.piezaDeEnlace(item) end
    if not pz and id then
      for _, c in ipairs(candidatosRef(p) or {}) do
        if c.id == id then pz = { inv = c.inv, st = c.st, ar = c.ar, dps = c.dps, id = id, sub = c.sub }; break end
      end
      if not pz and WowF.piezaDeEnlace then pz = WowF.piezaDeEnlace("item:" .. id) end
    end
    if type(pz) ~= "table" or not pz.inv then return nil end
    pz.id = pz.id or id
    local antes = WowF.puntuacionEquipo(p)
    if type(antes) ~= "table" or antes.sinDatos or type(antes.total) ~= "number" then return nil end
    if slot then
      if not invEn(INV_DE_RANURA[slot] or {}, pz.inv) then return nil end
    else
      local opc = HUECOS_DE_INV[pz.inv]
      if not opc then return nil end
      -- One-Hand: Main Hand, o el arma mas floja de las dos si tu rama lleva dos armas y ya puedes
      if pz.inv == 13 and p.manos == "dobleEmpunadura" and invEn(invsDe(17, nil), 13) then opc = { 16, 17 } end
      slot = opc[1]
      if opc[2] then
        -- Anillo, trinket o la segunda arma: frente al mas flojo (vacio primero)
        local h1, h2 = antes.porHueco[opc[1]], antes.porHueco[opc[2]]
        local v1, v2 = h1 and h1.valor or 0, h2 and h2.valor or 0
        if v2 < v1 then slot = opc[2] end
      end
    end
    local g = WowF.equipoGuia(p)
    local nivel = (type(g) == "table" and g.nivel) or nivelPj()
    local ok, despues = pcall(calcular, p, nivel, { slot = slot, pz = pz })
    if not ok or type(despues) ~= "table" or despues.sinDatos or type(despues.total) ~= "number" then return nil end
    local ha, hd = antes.porHueco[slot], despues.porHueco[slot]
    -- Estadisticas: las 3-5 de mas peso en tu rama + Armor, sumadas en todo tu equipo
    local orden = {}
    for k, w in pairs(p.pesos) do if type(k) == "number" and type(w) == "number" and w > 0 and NOMBRE_STAT[k] then orden[#orden + 1] = { k, w } end end
    table.sort(orden, function(a, b) return a[2] > b[2] end)
    local elegidas = {}
    for i, x in ipairs(orden) do
      if i > 5 or (i > 3 and x[2] < orden[1][2] * 0.4) then break end
      elegidas[#elegidas + 1] = x[1]
    end
    local function sumar(piezas)
      local t = { ar = 0 }
      for _, s in ipairs(ORDEN_HUECOS) do
        local q = piezas[s]
        if type(q) == "table" then
          local l = q.st or {}
          for i = 1, #l - 1, 2 do t[l[i]] = (t[l[i]] or 0) + (tonumber(l[i + 1]) or 0) end
          t.ar = t.ar + (tonumber(q.ar) or 0)
        end
      end
      return t
    end
    local sa, sd = sumar(antes.piezas or {}), sumar(despues.piezas or {})
    -- Con un arma de dos manos nueva, la Off Hand se queda fuera
    if pz.inv == 17 and slot == 16 and type((despues.piezas or {})[17]) == "table" then
      local q = despues.piezas[17]
      local l = q.st or {}
      for i = 1, #l - 1, 2 do sd[l[i]] = (sd[l[i]] or 0) - (tonumber(l[i + 1]) or 0) end
      sd.ar = sd.ar - (tonumber(q.ar) or 0)
    end
    local stats = {}
    for _, k in ipairs(elegidas) do stats[#stats + 1] = { nombre = NOMBRE_STAT[k], antes = sa[k] or 0, despues = sd[k] or 0 } end
    stats[#stats + 1] = { nombre = "Armor", antes = sa.ar, despues = sd.ar }
    return { antes = antes.total, despues = despues.total, slot = slot,
      hueco = { antes = ha and math.floor(ha.valor + 0.5) or nil, despues = hd and math.floor(hd.valor + 0.5) or nil },
      stats = stats }
  end

  -- Lineas (ya en tu idioma) para el tooltip de la puntuacion
  function WowF.puntuacionExplicacion(res)
    if type(res) ~= "table" or res.sinDatos or type(res.total) ~= "number" then
      return { (type(res) == "table" and res.aviso) or sinDatosTxt() }
    end
    local l = {}
    l[#l + 1] = L("100 = lo mejor verificado de WoW Forever que ya puedes usar en cada hueco (misiones y mazmorras para tu nivel y tu rama).",
      "100 = the best verified WoW Forever gear you can already use in each slot (quests and dungeons for your level and spec).")
    local dobles = {}
    for _, h in ipairs(res.huecosDetalle or {}) do if (h.peso or 1) > 1 then dobles[#dobles + 1] = h.nombre end end
    local n = tonumber(res.cuenta) or 0
    if #dobles > 0 then
      l[#l + 1] = L("Es la media de " .. n .. " huecos; las armas cuentan doble (" .. table.concat(dobles, ", ") .. ").",
        "It is the average of " .. n .. " slots; weapons count double (" .. table.concat(dobles, ", ") .. ").")
    else
      l[#l + 1] = L("Es la media de " .. n .. " huecos.", "It is the average of " .. n .. " slots.")
    end
    if res.dosManos and res.armasBloque then
      l[#l + 1] = L("Llevas un arma de dos manos: cuenta por las dos manos y se compara también con la mejor pareja Main Hand + Off Hand.",
        "You wear a two-handed weapon: it counts for both hands and is also compared with the best Main Hand + Off Hand pair.")
    elseif res.dosManos then
      l[#l + 1] = L("Con un arma de dos manos, la Off Hand no cuenta.", "With a two-handed weapon, the Off Hand does not count.")
    elseif res.armasBloque and res.porHueco and res.porHueco[17] then
      l[#l + 1] = L("Tus dos armas se comparan como pareja, también contra la mejor arma de dos manos.",
        "Your two weapons are compared as a pair, also against the best two-handed weapon.")
    end
    local h16 = res.porHueco and res.porHueco[16]
    if h16 and h16.nota == "dosManos" then
      l[#l + 1] = L("Un arma de dos manos que ya puedes usar te da más que tu pareja de armas: por eso tus manos quedan por debajo de 100.",
        "A two-handed weapon you can already use beats your weapon pair: that is why your hands are below 100.")
    elseif h16 and h16.nota == "pareja" then
      l[#l + 1] = L("Una pareja de armas (Main Hand + Off Hand) que ya puedes usar te da más que tu arma de dos manos.",
        "A weapon pair (Main Hand + Off Hand) you can already use beats your two-handed weapon.")
    end
    l[#l + 1] = L("Un hueco vacío vale 0.", "An empty slot is worth 0.")
    l[#l + 1] = L("Los filtros (Todo, Misiones, Mazmorras, Fabricar, Comprar) no cambian este número.",
      "The filters (All, Quests, Dungeons, Crafting, Buy) do not change this number.")
    local flojos = {}
    for i = 1, math.min(3, #(res.huecosDetalle or {})) do
      local h = res.huecosDetalle[i]
      if h.valor < 95 then flojos[#flojos + 1] = h.nombre .. " " .. (h.vacio and L("vacío", "empty") or tostring(h.valor)) end
    end
    if #flojos > 0 then
      l[#l + 1] = L("Lo más flojo: ", "Weakest: ") .. table.concat(flojos, ", ") .. "."
    else
      l[#l + 1] = L("Ningún hueco está por debajo de 95: vas bien.", "No slot is below 95: you are doing well.")
    end
    return l
  end

  -- Puesto de lo que llevas en un hueco entre lo que ya puedes usar (misma referencia que la puntuacion):
  -- { rango (1 = lo mejor), top = { { c, puntos, rango, texto, llevas } x3 }, texto, valor, estado }
  function WowF.rangoHueco(slot, p)
    p = p or (WowF.armarPlan and WowF.armarPlan())
    if type(p) ~= "table" or not p.pesos then return { texto = sinDatosTxt(), sinDatos = true } end
    local g = WowF.equipoGuia(p)
    if type(g) ~= "table" then return { texto = sinDatosTxt(), sinDatos = true } end
    local todos = candidatosRef(p)
    if type(todos) ~= "table" then return { texto = sinDatosTxt(), sinDatos = true } end
    local nivel = g.nivel or nivelPj()
    local pw = pesosRama(p)
    local pz = piezaPuesta(slot)
    local res = { top = {} }
    if slot == 17 and dosManosDe(p, { [16] = piezaPuesta(16) }) then
      res.texto = Y(L("Con un arma de dos manos, este hueco no cuenta.", "With a two-handed weapon, this slot does not count."))
      return res
    end
    local invs = invsDe(slot, slot == 17 and pz or nil)
    local lista = listaHueco(todos, invs, function(c) return usableYa(c, nivel, p, slot) end, pw, nivel)
    local puesto = (pz == false) and 0 or (type(pz) == "table" and valorPieza(pz, pw, nivel)) or nil
    local miId = type(pz) == "table" and pz.id or nil
    for i = 1, math.min(3, #lista) do
      local x = lista[i]
      table.insert(res.top, { c = x.c, puntos = x.v, rango = i, texto = Y(L("#" .. i .. " para tu nivel", "#" .. i .. " for your level")), llevas = (miId ~= nil and x.c.id == miId) })
    end
    local pu = WowF.puntuacionEquipo(p)
    local h = type(pu) == "table" and pu.porHueco and pu.porHueco[slot]
    if h then res.valor, res.estado = math.floor(h.valor + 0.5), h.estado end
    if puesto == nil then res.texto = L("No se pudo leer lo que llevas en este hueco.", "Could not read what you wear in this slot.")
    elseif #lista == 0 then res.texto = sinDatosTxt(); res.sinDatos = true
    else
      local k = 1
      for _, x in ipairs(lista) do if x.c.id ~= miId and x.v > puesto + 0.001 then k = k + 1 end end
      res.rango = k
      if puesto <= 0 then res.texto = L("Hueco vacío: cualquiera de la lista te sube.", "Empty slot: anything on the list is an upgrade.")
      elseif k == 1 and (not h or h.valor >= 95) then res.texto = L("Ya tienes la #1 de este hueco", "You already have the #1 for this slot")
      else res.texto = L("Lo tuyo es la #" .. math.max(k, 2) .. " para tu nivel", "Yours is #" .. math.max(k, 2) .. " for your level") end
      -- 13-oct: armas como bloque (pareja frente a dos manos)
      if puesto > 0 and h and h.nota == "dosManos" then
        res.texto = L("Un arma de dos manos te da más que tu pareja de armas", "A two-handed weapon beats your weapon pair")
      elseif puesto > 0 and h and h.nota == "pareja" then
        res.texto = L("Una pareja Main Hand + Off Hand te da más que tu arma de dos manos", "A Main Hand + Off Hand pair beats your two-handed weapon")
      end
    end
    res.texto = Y(res.texto)
    return res
  end
end

-- Frase de la puntuacion (tooltip del panel y linea de la pestana Equipo)
function WowF.puntuacionFrase(pu)
  if type(pu) ~= "table" or pu.sinDatos or type(pu.total) ~= "number" then return (type(pu) == "table" and pu.aviso) or sinDatosTxt() end
  local v = pu.total
  local t
  if v > 75 then t = L("Vas bien: tu equipo está a " .. v .. " de 100 frente a lo mejor que puedes tener ya.", "Looking good: your gear is at " .. v .. " out of 100 against the best you can get now.")
  elseif v >= 40 then t = L("Tu equipo está a " .. v .. " de 100 frente a lo mejor que puedes tener ya: hay mejoras a tu alcance.", "Your gear is at " .. v .. " out of 100 against the best you can get now: there are upgrades within reach.")
  else t = L("Tu equipo está flojo: " .. v .. " de 100 frente a lo mejor que puedes tener ya. Empieza por los huecos en rojo.", "Your gear is weak: " .. v .. " out of 100 against the best you can get now. Start with the red slots.") end
  local n = tonumber(pu.faltan) or 0
  if n == 1 then t = t .. "\n" .. L("Te falta 1 mejora fácil: ya la puedes conseguir.", "You are missing 1 easy upgrade: you can get it now.")
  elseif n > 1 then t = t .. "\n" .. L("Te faltan " .. n .. " mejoras fáciles: ya las puedes conseguir.", "You are missing " .. n .. " easy upgrades: you can get them now.") end
  local h = pu.peor and pu.porHueco and pu.porHueco[pu.peor]
  if h then
    t = t .. "\n" .. L("Lo que más sube: ", "Biggest gain: ") .. h.nombre .. (h.vacio and L(" (vacío)", " (empty)") or (" (" .. math.floor(h.valor + 0.5) .. " / 100)"))
  end
  if pu.marcas and pu.marcas.ahora then
    t = t .. "\n" .. L("Frente a la BiS de nivel 30: lo tuyo " .. (pu.barra or 0) .. " %, lo que puedes tener ya " .. pu.marcas.ahora .. " %.",
      "Against level 30 BiS: yours " .. (pu.barra or 0) .. " %, what you can get now " .. pu.marcas.ahora .. " %.")
  end
  t = t .. "\n" .. L("Es una puntuación general: compara lo que llevas con lo mejor verificado para tu nivel y tu rama (misiones y mazmorras de WoW Forever). Los filtros (Todo, Misiones, Fabricar...) solo cambian la lista de abajo, no este número.",
    "This is an overall score: it compares what you wear with the best verified gear for your level and spec (WoW Forever quests and dungeons). The filters (All, Quests, Crafting...) only change the list below, not this number.")
  return Y(t)
end


-- Escala con el personaje: cualquier cambio de nivel, equipo, habilidades, bolsas o misiones borra la cache
if CreateFrame then
  local f = CreateFrame("Frame")
  for _, ev in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, ev)
  end
  f:SetScript("OnEvent", function() cache, claveCache, cacheRef, claveRef = nil, nil, nil, nil end)
end
WowF.equipoGuiaLimpiar = function() cache, claveCache, cacheRef, claveRef = nil, nil, nil, nil end
