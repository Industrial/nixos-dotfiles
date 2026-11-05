-- wowF DiarioRuta: pestana "Ruta" de la ficha de cada mazmorra del Diario (12-oct).
-- Un esquema de arriba abajo con TODO lo que hay que hacer para una mazmorra: nivel, lineas de misiones previas, misiones de
-- fuera (quien, donde, nivel), entrar, las misiones que se recogen dentro (recuadro al lado) y a quien entregarlas.
-- Idea tomada de otros addons de "attunement"; codigo y datos propios: solo WoW Forever (wowF_Mazmorras.lua, de Wowhead /forever
-- y del cliente de la beta). Sin dato = aviso "aun no hay datos de WoW Forever; pendiente de actualizar", nunca inventado.
-- Colores: verde = hecho, amarillo = en tu registro, gris = pendiente, rojo = te falta nivel, azul que late = el siguiente paso.
-- Clic en una caja = la ruta de siempre (WowF.irAMision / irALinea / irAEntrega / diarioVerEnMapa o irAMazmorra).
-- Todo en la tabla R (tope de 200 locales). Bilingue con L(es, en).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local R = { cajas = {}, nc = 0, lineas = {}, nl = 0, texs = {}, nt = 0, filas = {}, nf = 0, textos = {}, ntx = 0, estado = {} }

R.COL = {
  hecho = { borde = { 0.3, 0.85, 0.4 }, fondo = { 0.07, 0.19, 0.09 } },
  registro = { borde = { 1, 0.82, 0.2 }, fondo = { 0.22, 0.17, 0.04 } },
  pendiente = { borde = { 0.45, 0.43, 0.4 }, fondo = { 0.1, 0.09, 0.08 } },
  nivel = { borde = { 1, 0.3, 0.25 }, fondo = { 0.22, 0.06, 0.05 } },
  sindatos = { borde = { 0.9, 0.55, 0.2 }, fondo = { 0.15, 0.1, 0.05 } },
}
R.AZUL = { 0.35, 0.65, 1 }
R.TXT = { hecho = "|cff4cd964", registro = "|cffffd133", pendiente = "|cffa39a8c", nivel = "|cffff5544", sindatos = "|cffff9933" }
R.ICONO_MISION = "Interface\\GossipFrame\\AvailableQuestIcon"
R.ICONO_ACTIVA = "Interface\\GossipFrame\\ActiveQuestIcon"
R.ICONO_LINEA = "Interface\\Icons\\INV_Misc_Book_09"
R.ICONO_MAZMORRA = "Interface\\Icons\\INV_Misc_Key_03"
R.SIN_DATOS = function() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end

-- ===================== Lectura segura del juego =====================
function R.num(v)
  if WowF.numero then return tonumber(WowF.numero(v)) end -- WowF.numero devuelve TEXTO
  if v == nil then return nil end
  if issecretvalue then local ok, s = pcall(issecretvalue, v); if not ok or s then return nil end end
  return tonumber(v)
end
function R.nivel()
  local ok, n = pcall(UnitLevel, "player")
  return (ok and R.num(n)) or 1
end
function R.hecha(id)
  id = tonumber(id)
  if not id then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
    if ok and r == true then return true end
  elseif IsQuestFlaggedCompleted then
    local ok, r = pcall(IsQuestFlaggedCompleted, id)
    if ok and r == true then return true end
  end
  return false
end
function R.enRegistro(id)
  id = tonumber(id)
  if not id or not C_QuestLog or not C_QuestLog.GetLogIndexForQuestID then return false end
  local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, id)
  i = ok and R.num(i) or nil
  return (i ~= nil and i > 0) and true or false
end
function R.lista(id)
  id = tonumber(id)
  if not id or not C_QuestLog or not C_QuestLog.IsComplete then return false end
  local ok, r = pcall(C_QuestLog.IsComplete, id)
  return ok and r == true
end
-- Dentro de ESTA mazmorra: IsInInstance + el id de instancia (8.o valor de GetInstanceInfo) igual al de la mazmorra (m.i)
function R.estasDentro(m)
  if not m or not m.i or not IsInInstance or not GetInstanceInfo then return false end
  local ok, dentro = pcall(IsInInstance)
  if not ok or dentro ~= true then return false end
  local ok2, id = pcall(function() return (select(8, GetInstanceInfo())) end)
  return ok2 and R.num(id) == m.i
end
function R.zona(mapa)
  if not mapa or mapa <= 0 or not WowF.nombreZona then return "" end
  local ok, z = pcall(WowF.nombreZona, mapa)
  return (ok and type(z) == "string") and z or ""
end

-- ===================== Pasos (sin interfaz) =====================
-- WowF.progresoMazmorra(m) -> { hechos, total, pasos = { { tipo, n, det, estado, icono | ret, accion, fila, cuenta, siguiente }... } }
-- tipo: "nivel" | "linea" | "fuera" | "entrar" | "dentro" | "entrega" | "aviso"; estado: "hecho" | "registro" | "pendiente" | "nivel" | "sindatos"
-- fila: los pasos con la misma fila van uno al lado del otro; "dentro" va en el recuadro lateral junto a "entrar".
function R.estadoMision(q, nivel)
  if q.hecha or R.hecha(q.id) then return "hecho" end
  if R.enRegistro(q.id) then return "registro" end
  if nivel < (q.nivel or 0) then return "nivel" end
  return "pendiente"
end
-- 12-oct (Andy: "cada caja tiene que explicar que es, por que falta y que hacer"): cada paso lleva
--   det   = una linea corta en la caja (estado + que hacer),
--   exp   = lineas largas del tooltip (que es, de donde sale el dato, por que falta),
--   hacer = la frase de "QUE HACER AHORA" cuando es el paso azul.
-- A quien se entrega, en una frase (nil = sin dato de WoW Forever)
function R.entTxt(q)
  local e = WowF.entregaMision and WowF.entregaMision(q)
  if type(e) ~= "table" or not e.n or e.n == "" then return nil end
  if e.d then return e.n .. L(" (dentro de la mazmorra)", " (inside the dungeon)") end
  local z = R.zona(e.m)
  return e.n .. ((z ~= "") and (L(" en ", " in ") .. z) or "")
end
function R.entFrase(q) return R.entTxt(q) or (L("a quién se entrega: ", "turn-in: ") .. R.SIN_DATOS()) end
-- Misiones que Blizzard no usa ("<UNUSED>", "<NYI> <TXT>..."): nunca se ensenan
function R.basura(q) return type(q) ~= "table" or type(q.n) ~= "string" or q.n:find("^%s*<") ~= nil end
function R.conNpc(q) return type(q.quien) == "string" and q.quien ~= "" end

function R.pasoLinea(q, nivel)
  local c = q.cadena
  local tot, k, actual = #c, nil, nil
  for i, p in ipairs(c) do if not R.hecha(p.i) then k, actual = i, p; break end end
  local paso = { tipo = "linea", icono = R.ICONO_LINEA, cuenta = true, q = q,
    n = L("Línea previa: ", "Prior questline: ") .. (q.n or "?") }
  paso.exp = { L("Antes de poder coger " .. (q.n or "?") .. " hay que hacer " .. tot .. " misiones seguidas: sin ellas, el NPC no te la da.",
    "Before you can pick up " .. (q.n or "?") .. " you must do " .. tot .. " quests in a row: without them, the NPC will not give it to you.") }
  if not k then
    paso.estado = "hecho"
    paso.det = L("hecha (" .. tot .. " de " .. tot .. ")", "done (" .. tot .. " of " .. tot .. ")")
  else
    local reg = R.enRegistro(actual.i)
    local quien = (type(actual.q) == "string" and actual.q ~= "") and actual.q or nil
    paso.estado = reg and "registro" or ((actual.l and nivel < actual.l) and "nivel" or "pendiente")
    paso.det = L("parte " .. k .. " de " .. tot .. ": ", "part " .. k .. " of " .. tot .. ": ") .. (actual.n or "?")
      .. ((paso.estado == "nivel") and L(" · desde nivel " .. actual.l, " · from level " .. actual.l) or "")
      .. ((not reg and quien) and (" · " .. quien) or "")
    table.insert(paso.exp, L("Ahora toca la parte " .. k .. " de " .. tot .. ": " .. (actual.n or "?") .. ".", "Now: part " .. k .. " of " .. tot .. ": " .. (actual.n or "?") .. "."))
    if paso.estado == "registro" then
      paso.hacer = L("Termina " .. (actual.n or "?") .. " (parte " .. k .. " de " .. tot .. " de la línea previa) y entrégala.",
        "Finish " .. (actual.n or "?") .. " (part " .. k .. " of " .. tot .. " of the prior questline) and turn it in.")
    elseif paso.estado == "nivel" then
      paso.hacer = L("La línea previa sigue en nivel " .. actual.l .. ": sube de nivel para continuarla.", "The prior questline continues at level " .. actual.l .. ": level up to continue it.")
    else
      paso.hacer = L("Haz la línea previa, parte " .. k .. " de " .. tot .. ": " .. (actual.n or "?") .. (quien and (", te la da " .. quien) or "") .. ".",
        "Do the prior questline, part " .. k .. " of " .. tot .. ": " .. (actual.n or "?") .. (quien and (", given by " .. quien) or "") .. ".")
    end
  end
  paso.accion = function() if WowF.irALinea then WowF.irALinea(q) end end
  paso.ayuda = L("Clic: guía paso a paso de la línea (ventana y ruta).", "Click: step-by-step guide for the questline (window and route).")
  return paso
end

-- Linea del tooltip con el estado de una mision (comun a fuera y dentro)
function R.expEstado(q, est, nivel)
  if est == "hecho" then return L("Ya la entregaste: no tienes que hacer nada más con ella.", "You already turned it in: nothing else to do with it.") end
  if est == "nivel" then return L("Aún no te la dan: necesitas nivel " .. (q.nivel or "?") .. " (eres " .. nivel .. ").", "Not available yet: you need level " .. (q.nivel or "?") .. " (you are " .. nivel .. ").") end
  if est == "registro" then
    if R.lista(q.id) then return L("Ya la cumpliste: solo falta entregarla.", "You completed it: you only need to turn it in.") end
    return L("Está en tu registro de misiones (tecla L): cúmplela y entrégala.", "It is in your quest log (L key): complete it and turn it in.")
  end
  return L("Aún no la tienes: ve a por ella.", "You do not have it yet: go get it.")
end

function WowF.progresoMazmorra(m)
  local res = { hechos = 0, total = 0, pasos = {} }
  if type(m) ~= "table" then return res end
  local nivel = R.nivel()
  local pasos = res.pasos
  local function poner(p) table.insert(pasos, p) end
  -- 1. Nivel
  local d, h = m.d or 0, m.h or m.d or 0
  local falta = math.max(0, d - nivel)
  poner({ tipo = "nivel", fila = 1, cuenta = true, ret = { unidad = "player", icono = R.ICONO_MAZMORRA },
    n = L("Nivel " .. d, "Level " .. d),
    det = (falta == 0) and L("lo tienes (eres " .. nivel .. ")", "you have it (you are " .. nivel .. ")")
      or L("te falta" .. (falta == 1 and "" or "n") .. " " .. falta .. (falta == 1 and " nivel" or " niveles") .. " (eres " .. nivel .. ")", "you need " .. falta .. (falta == 1 and " more level" or " more levels") .. " (you are " .. nivel .. ")"),
    estado = (falta == 0) and "hecho" or "nivel",
    exp = { L("Niveles de esta mazmorra en WoW Forever: " .. d .. "-" .. h .. ".", "Levels of this dungeon in WoW Forever: " .. d .. "-" .. h .. ".") },
    hacer = L("Sube a nivel " .. d .. " (te falta" .. (falta == 1 and "" or "n") .. " " .. falta .. "). Mientras, coge las misiones de fuera que ya te dan.",
      "Reach level " .. d .. " (" .. falta .. " to go). Meanwhile, pick up the outside quests you can already get.") })
  local lista = {}
  if WowF.misionesDe then
    local ok, l = pcall(WowF.misionesDe, m)
    if ok and type(l) == "table" then for _, q in ipairs(l) do if not R.basura(q) then table.insert(lista, q) end end end
  end
  -- 2. Lineas de misiones previas (una caja por linea; la misma linea no se repite)
  local vistas, fila = {}, 2
  for _, q in ipairs(lista) do
    local c = q.cadena
    if type(c) == "table" and #c > 1 and c[1].i and not vistas[c[1].i] then
      vistas[c[1].i] = true
      local p = R.pasoLinea(q, nivel); p.fila = fila; poner(p)
    end
  end
  -- 3. Misiones de fuera
  local hayDentroHecha = false
  for _, q in ipairs(lista) do
    local est = R.estadoMision(q, nivel)
    if q.dentro then
      if est == "hecho" or est == "registro" then hayDentroHecha = true end
    else
      local z = R.zona(q.m)
      local quien = R.conNpc(q) and q.quien or "?"
      local enZona = (z ~= "") and (L(" en ", " in ") .. z) or (" · " .. L("sitio: ", "place: ") .. R.SIN_DATOS())
      local entF = R.entFrase(q)
      local lista_ = (est == "registro") and R.lista(q.id)
      local det, hacer
      if est == "nivel" then
        det = L("desde nivel " .. (q.nivel or "?") .. " (eres " .. nivel .. ") · " .. quien, "from level " .. (q.nivel or "?") .. " (you are " .. nivel .. ") · " .. quien)
        hacer = L("Sube a nivel " .. (q.nivel or "?") .. " para coger " .. (q.n or "?") .. " (la da " .. quien .. enZona .. ").", "Reach level " .. (q.nivel or "?") .. " to pick up " .. (q.n or "?") .. " (from " .. quien .. enZona .. ").")
      elseif est == "hecho" then
        det = L("entregada", "turned in")
      elseif est == "registro" then
        det = lista_ and (L("¡lista! entrégala a ", "ready! turn it in to ") .. entF) or (L("aceptada: cúmplela y entrégala a ", "accepted: complete it, turn in to ") .. entF)
        hacer = lista_ and L("Entrega " .. (q.n or "?") .. " a " .. entF .. ".", "Turn in " .. (q.n or "?") .. " to " .. entF .. ".")
          or L("Ya tienes " .. (q.n or "?") .. ": cúmplela (en la mazmorra) y entrégala a " .. entF .. ".", "You have " .. (q.n or "?") .. ": complete it (in the dungeon) and turn it in to " .. entF .. ".")
      else
        det = L("habla con ", "talk to ") .. quien .. enZona
        hacer = L("Habla con " .. quien .. enZona .. " y acepta " .. (q.n or "?") .. ", antes de entrar.", "Talk to " .. quien .. enZona .. " and accept " .. (q.n or "?") .. " before going in.")
      end
      hacer = hacer and (hacer .. " " .. L("Clic en la caja azul: te llevo.", "Click the blue box: I will take you.")) or nil
      local g = { quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } }
      poner({ tipo = "fuera", fila = 3, cuenta = true, n = q.n or "?", det = det, estado = est, q = q, hacer = hacer,
        exp = { L("Misión de FUERA: se coge antes de entrar. La da " .. quien .. enZona .. ", desde nivel " .. (q.nivel or "?") .. ".",
            "OUTSIDE quest: picked up before going in. Given by " .. quien .. enZona .. ", from level " .. (q.nivel or "?") .. "."),
          L("Se entrega a: ", "Turn in to: ") .. entF, R.expEstado(q, est, nivel) },
        ret = { npc = q.npc, nombre = q.quien, icono = R.ICONO_MISION },
        accion = function()
          if est == "registro" and WowF.irAEntrega then WowF.irAEntrega(q) elseif WowF.irAMision then WowF.irAMision(g) end
        end,
        ayuda = (est == "registro") and L("Clic: ruta a quien la recibe.", "Click: route to who takes it.") or L("Clic: ruta hasta quien la da.", "Click: route to who gives it.") })
    end
  end
  -- 4. Entrar. Hecho SOLO si se sabe sin adivinar: estas dentro ahora, o ya cogiste/entregaste una mision que se recoge dentro.
  local dentroAhora = R.estasDentro(m)
  local zonaEnt = m.z or R.zona(m.m)
  local entra = { tipo = "entrar", fila = 4, cuenta = true, n = L("Entra en ", "Enter ") .. (m.n or "?"),
    icono = R.ICONO_MAZMORRA, estado = (dentroAhora or hayDentroHecha) and "hecho" or ((nivel < d) and "nivel" or "pendiente") }
  if dentroAhora then entra.det = L("estás dentro ahora", "you are inside now")
  elseif not m.m then entra.det = L("entrada: ", "entrance: ") .. R.SIN_DATOS()
  else entra.det = L("entrada en ", "entrance in ") .. (zonaEnt or "?") .. (m.a and L(" · sin confirmar", " · not confirmed") or "") end
  entra.exp = { m.m and L("La entrada está en " .. (zonaEnt or "?") .. ". Ve con tu grupo.", "The entrance is in " .. (zonaEnt or "?") .. ". Go with your group.")
      or L("La entrada de esta mazmorra: ", "This dungeon's entrance: ") .. R.SIN_DATOS(),
    L("Se marca hecha cuando estás dentro o ya cogiste una misión de dentro.", "It turns done when you are inside or already picked up an inside quest.") }
  entra.hacer = m.m and L("Ve a la entrada de " .. (m.n or "?") .. " en " .. (zonaEnt or "?") .. " y entra con tu grupo. Clic en la caja azul: te llevo.",
      "Go to the entrance of " .. (m.n or "?") .. " in " .. (zonaEnt or "?") .. " and go in with your group. Click the blue box: I will take you.")
    or L("Entra en " .. (m.n or "?") .. " con tu grupo (la entrada: " .. R.SIN_DATOS() .. ").", "Enter " .. (m.n or "?") .. " with your group (entrance: " .. R.SIN_DATOS() .. ").")
  if WowFDiario and WowFDiario[m.i] and WowFDiario[m.i].mini then entra.mini = WowFDiario[m.i].mini end
  entra.accion = function()
    if WowF.diarioVerEnMapa then WowF.diarioVerEnMapa(m) elseif WowF.irAMazmorra then WowF.irAMazmorra(m) end
  end
  entra.ayuda = L("Clic: ruta hasta la entrada.", "Click: route to the entrance.")
  poner(entra)
  -- 5. Dentro de la mazmorra (recuadro lateral): como empieza cada una (NPC de dentro, u objeto/algo que encuentras sin NPC)
  local nDentro = 0
  for _, q in ipairs(lista) do
    if q.dentro then
      nDentro = nDentro + 1
      local est = R.estadoMision(q, nivel)
      local npc = R.conNpc(q)
      local entF = R.entFrase(q)
      local det, hacer
      if est == "nivel" then det = L("desde nivel " .. (q.nivel or "?"), "from level " .. (q.nivel or "?"))
      elseif est == "hecho" then det = L("entregada", "turned in")
      elseif est == "registro" then
        det = R.lista(q.id) and (L("¡lista! entrégala a ", "ready! turn in to ") .. entF) or (L("cúmplela y entrégala a ", "complete it, turn in to ") .. entF)
        hacer = L("Cumple " .. (q.n or "?") .. " y entrégala a " .. entF .. ".", "Complete " .. (q.n or "?") .. " and turn it in to " .. entF .. ".")
      elseif npc then
        det = L("la da " .. q.quien .. " dentro", "given by " .. q.quien .. " inside")
        hacer = L("Dentro de la mazmorra, habla con " .. q.quien .. " y acepta " .. (q.n or "?") .. ".", "Inside the dungeon, talk to " .. q.quien .. " and accept " .. (q.n or "?") .. ".")
      else
        det = L("empieza con un objeto de dentro", "starts from an item inside")
        hacer = L("Dentro, " .. (q.n or "?") .. " empieza sin NPC: con un objeto que te cae o encuentras allí. Al tenerlo, haz clic derecho en él y acéptala.",
          "Inside, " .. (q.n or "?") .. " starts without an NPC: from an item that drops or you find there. When you have it, right-click it and accept.")
      end
      local exp = { npc and L("Misión de DENTRO: la da " .. q.quien .. " dentro de la mazmorra.", "INSIDE quest: given by " .. q.quien .. " inside the dungeon.")
          or L("Misión de DENTRO sin NPC: empieza con un objeto que te cae o que encuentras en la mazmorra (clic derecho en él para aceptarla).",
            "INSIDE quest with no NPC: it starts from an item that drops or that you find in the dungeon (right-click it to accept)."),
        L("Desde nivel ", "From level ") .. (q.nivel or "?") .. " · " .. L("se entrega a: ", "turn in to: ") .. entF, R.expEstado(q, est, nivel) }
      poner({ tipo = "dentro", fila = 4, cuenta = true, n = q.n or "?", estado = est, q = q, det = det, exp = exp, hacer = hacer,
        accion = function()
          if est == "registro" and WowF.irAEntrega then WowF.irAEntrega(q)
          elseif npc and WowF.irAMision then WowF.irAMision({ quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } })
          elseif WowF.diarioVerEnMapa then WowF.diarioVerEnMapa(m) elseif WowF.irAMazmorra then WowF.irAMazmorra(m) end
        end })
    end
  end
  if #lista == 0 then
    poner({ tipo = "aviso", fila = 4, lado = true, n = L("Misiones: ", "Quests: ") .. R.SIN_DATOS(), estado = "sindatos",
      exp = { L("Aún no sabemos qué misiones tiene esta mazmorra en WoW Forever. Se actualizará en próximas versiones.", "We do not know yet which quests this dungeon has in WoW Forever. It will be updated in future versions.") } })
  elseif nDentro == 0 then
    poner({ tipo = "aviso", fila = 4, lado = true, n = L("Ninguna empieza dentro: todas se cogen fuera.", "None starts inside: all are picked up outside."), estado = "pendiente",
      exp = { L("Todas las misiones de esta mazmorra se cogen FUERA, antes de entrar (cajas de arriba).", "All quests for this dungeon are picked up OUTSIDE, before going in (boxes above).") } })
  end
  -- Misiones de fuera que se ENTREGAN dentro (ej. Deathstalkers in Shadowfang -> Deathstalker Vincent)
  for _, q in ipairs(lista) do
    local e = (not q.dentro) and WowF.entregaMision and WowF.entregaMision(q)
    if type(e) == "table" and e.d and e.n and e.n ~= "" then
      local est = R.estadoMision(q, nivel)
      poner({ tipo = "aviso", fila = 4, lado = true, estado = (est == "hecho") and "hecho" or ((est == "registro") and "registro" or "pendiente"),
        n = L("Se entrega aquí: ", "Turned in here: ") .. (q.n or "?"), det = "→ " .. e.n,
        exp = { L((q.n or "?") .. " se coge fuera y se ENTREGA dentro, a " .. e.n .. ".", (q.n or "?") .. " is picked up outside and turned in INSIDE, to " .. e.n .. "."), R.expEstado(q, est, nivel) } })
    end
  end
  -- 6. Entregar: una caja por NPC que recibe (ent de cada mision); sin dato = aviso
  local grupos, orden, sinEnt = {}, {}, {}
  for _, q in ipairs(lista) do
    local e = WowF.entregaMision and WowF.entregaMision(q)
    if type(e) == "table" and e.n and e.n ~= "" then
      local clave = e.n .. "|" .. tostring(e.m or 0)
      if not grupos[clave] then grupos[clave] = { e = e, q = {} }; table.insert(orden, clave) end
      table.insert(grupos[clave].q, q)
    else table.insert(sinEnt, q) end
  end
  for _, clave in ipairs(orden) do
    local gr = grupos[clave]
    local e = gr.e
    local hechas, reg, listas, nivelFalta, elegir = 0, false, false, true, nil
    local nombres = {}
    for _, q in ipairs(gr.q) do
      table.insert(nombres, q.n or "?")
      local est = R.estadoMision(q, nivel)
      if est == "hecho" then hechas = hechas + 1
      else
        if est == "registro" then reg = true; if R.lista(q.id) then listas = true end; elegir = elegir or q end
        if est ~= "nivel" then nivelFalta = false end
      end
    end
    local estado = (hechas == #gr.q) and "hecho" or (reg and "registro" or (nivelFalta and "nivel" or "pendiente"))
    local donde = e.d and L("dentro de la mazmorra", "inside the dungeon") or R.zona(e.m)
    if donde == "" then donde = L("sitio: ", "place: ") .. R.SIN_DATOS() end
    local det = donde .. " · " .. hechas .. "/" .. #gr.q .. L(" entregadas", " turned in")
    if listas then det = L("¡lista para entregar! · ", "ready to turn in! · ") .. det end
    local qq = elegir or gr.q[1]
    local lst = table.concat(nombres, ", ")
    poner({ tipo = "entrega", fila = 5, cuenta = true, n = L("Entrega a ", "Turn in to ") .. e.n, det = det, estado = estado,
      exp = { L(e.n .. " recibe: " .. lst .. ".", e.n .. " takes: " .. lst .. "."), L("Dónde: ", "Where: ") .. donde .. ".",
        (estado == "hecho") and L("Ya entregaste todas.", "You turned them all in.")
          or (listas and L("Tienes alguna lista: ve a entregarla.", "You have one ready: go turn it in.")
          or L("Primero acéptalas y cúmplelas; luego se entregan aquí.", "First accept and complete them; then turn them in here.")) },
      hacer = L("Entrega " .. lst .. " a " .. e.n .. " (" .. donde .. "). Clic en la caja azul: te llevo.", "Turn in " .. lst .. " to " .. e.n .. " (" .. donde .. "). Click the blue box: I will take you."),
      ret = { npc = e.id, nombre = e.n, icono = R.ICONO_ACTIVA },
      accion = function() if WowF.irAEntrega then WowF.irAEntrega(qq) end end,
      ayuda = L("Clic: ruta a quien la recibe y marca sobre su cabeza.", "Click: route to who takes it and a mark over their head.") })
  end
  if #sinEnt > 0 and #lista > 0 then
    local nombres = {}
    for i, q in ipairs(sinEnt) do if i <= 2 then table.insert(nombres, q.n or "?") end end
    local mas = #sinEnt - #nombres
    local lst = table.concat(nombres, ", ") .. ((mas > 0) and L(" y " .. mas .. " más", " and " .. mas .. " more") or "")
    poner({ tipo = "aviso", fila = 5, n = L("Entrega sin datos: ", "Turn-in unknown: ") .. lst, estado = "sindatos", icono = R.ICONO_ACTIVA,
      det = L("revisa a quién se entrega en tu registro (tecla L)", "check who takes it in your quest log (L key)"),
      exp = { L("A quién se entrega(n): ", "Who takes it: ") .. R.SIN_DATOS() .. ".",
        L("Cuando la aceptes, tu registro de misiones (tecla L) dice a quién entregarla.", "Once you accept it, your quest log (L key) says who to turn it in to.") } })
  end
  -- Cuenta y siguiente paso (el primero sin hacer al que ya llegas; si todos piden nivel, el primero sin hacer)
  local primero
  for _, p in ipairs(pasos) do
    if p.cuenta then
      res.total = res.total + 1
      if p.estado == "hecho" then res.hechos = res.hechos + 1
      elseif not res.siguiente and p.estado ~= "nivel" then res.siguiente = p
      elseif not primero then primero = p end
    end
  end
  res.siguiente = res.siguiente or primero
  if res.siguiente then res.siguiente.siguiente = true end
  if res.total > 0 and res.hechos == res.total then
    res.hacer = L("¡Todo hecho en esta mazmorra! No te queda nada pendiente aquí.", "All done in this dungeon! Nothing left to do here.")
  elseif res.siguiente then
    res.hacer = res.siguiente.hacer or ((res.siguiente.n or "") .. ((res.siguiente.det and res.siguiente.det ~= "") and (": " .. res.siguiente.det) or ""))
  end
  return res
end


-- ===================== Dibujo =====================
local function estilo() return WowF.estilo end
function R.crear(contenedor)
  if R.capa and R.padre == contenedor then return end
  R.padre = contenedor
  R.capa = CreateFrame("Frame", nil, contenedor)
  R.capa:SetAllPoints(contenedor)
  pcall(function() R.capa:SetFrameLevel((tonumber(contenedor:GetFrameLevel()) or 0) + 5) end)
  R.brillo = R.capa:CreateTexture(nil, "BACKGROUND", nil, 0)
  if R.brillo.SetColorTexture then R.brillo:SetColorTexture(R.AZUL[1], R.AZUL[2], R.AZUL[3], 1) end
  R.brillo:Hide()
  R.capa:SetScript("OnUpdate", function()
    if not R.brillo:IsShown() then return end
    local t = (GetTime and tonumber(GetTime())) or 0
    R.brillo:SetAlpha(0.35 + 0.35 * math.sin(t * 4))
  end)
  local E = estilo()
  if E and E.barra then R.barra = E.barra(R.capa, 200, "verde")
  else
    R.barra = CreateFrame("Frame", nil, R.capa); R.barra:SetSize(200, 8)
    R.barra.fondo = R.barra:CreateTexture(nil, "BACKGROUND"); R.barra.fondo:SetAllPoints()
    if R.barra.fondo.SetColorTexture then R.barra.fondo:SetColorTexture(0.08, 0.07, 0.06, 1) end
    R.barra.relleno = R.barra:CreateTexture(nil, "ARTWORK"); R.barra.relleno:SetPoint("TOPLEFT"); R.barra.relleno:SetHeight(8)
    if R.barra.relleno.SetColorTexture then R.barra.relleno:SetColorTexture(0.3, 0.85, 0.4, 1) end
    function R.barra:poner(v, mx)
      local f = (mx and mx > 0) and math.max(0, math.min(1, v / mx)) or 0
      local w = tonumber(self.GetWidth and self:GetWidth()) or 200
      if f <= 0 then self.relleno:Hide() else self.relleno:SetWidth(math.max(1, w * f)); self.relleno:Show() end
    end
  end
  pcall(function() R.barra:SetFrameLevel((tonumber(R.capa:GetFrameLevel()) or 0) + 2) end)
  R.barra:Hide()
  R.lado = CreateFrame("Frame", nil, R.capa)
  pcall(function() R.lado:SetFrameLevel((tonumber(R.capa:GetFrameLevel()) or 0) + 1) end)
  R.lado.borde = R.lado:CreateTexture(nil, "BACKGROUND", nil, 1); R.lado.borde:SetAllPoints()
  R.lado.fondo = R.lado:CreateTexture(nil, "BACKGROUND", nil, 2); R.lado.fondo:SetPoint("TOPLEFT", 1, -1); R.lado.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
  if R.lado.borde.SetColorTexture then R.lado.borde:SetColorTexture(0.42, 0.35, 0.23, 1); R.lado.fondo:SetColorTexture(0.07, 0.065, 0.06, 0.92) end
  R.lado:Hide()
end

function R.texto(x, y, ancho, s, tipo, tam, color)
  R.ntx = R.ntx + 1
  local f = R.textos[R.ntx]
  if not f then
    f = R.capa:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if f.SetWordWrap then f:SetWordWrap(true) end
    R.textos[R.ntx] = f
  end
  local E = estilo()
  if E then
    if tipo == "titulo" then pcall(E.titulo, R.capa, f, tam or 14)
    elseif tipo == "etiqueta" then pcall(E.etiqueta, R.capa, f, color or E.color.brasa, tam or 9)
    elseif tipo == "sub" then pcall(E.sub, R.capa, f, tam or 10)
    else pcall(E.cuerpo, R.capa, f, tam or 11, color) end
  end
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", R.padre, "TOPLEFT", x, -y); f:SetWidth(ancho)
  if f.SetJustifyH then f:SetJustifyH("LEFT") end
  f:SetText((tipo == "etiqueta" and E and E.mayus) and E.mayus(s) or s)
  f:Show()
  local alto = (f.GetStringHeight and R.num(f:GetStringHeight())) or 0
  if alto <= 0 then alto = (tam or 11) + 3 end
  return f, alto
end

-- Raya recta (todas son horizontales o verticales): CreateLine si existe; si no, una textura fina
function R.raya(x1, y1, x2, y2, col, a)
  local grueso = 2
  if R.capa.CreateLine then
    R.nl = R.nl + 1
    local l = R.lineas[R.nl]
    if not l then
      local ok, nueva = pcall(R.capa.CreateLine, R.capa, nil, "BORDER")
      if ok and nueva then l = nueva; R.lineas[R.nl] = l else R.nl = R.nl - 1 end
    end
    if l then
      local ok = pcall(function()
        l:SetThickness(grueso)
        l:SetColorTexture(col[1], col[2], col[3], a or 1)
        l:SetStartPoint("TOPLEFT", R.padre, x1, -y1)
        l:SetEndPoint("TOPLEFT", R.padre, x2, -y2)
        l:Show()
      end)
      if ok then return end
    end
  end
  R.nt = R.nt + 1
  local t = R.texs[R.nt]
  if not t then t = R.capa:CreateTexture(nil, "BORDER", nil, 1); R.texs[R.nt] = t end
  local x, y = math.min(x1, x2), math.min(y1, y2)
  local w, h = math.max(grueso, math.abs(x2 - x1)), math.max(grueso, math.abs(y2 - y1))
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", R.padre, "TOPLEFT", x - (x1 == x2 and 1 or 0), -(y - (y1 == y2 and 1 or 0))); t:SetSize(w, h)
  if t.SetColorTexture then t:SetColorTexture(col[1], col[2], col[3], a or 1) end
  t:Show()
end

function R.nuevaCaja()
  local b = CreateFrame("Button", nil, R.capa)
  pcall(function() b:SetFrameLevel((tonumber(R.capa:GetFrameLevel()) or 0) + 3) end)
  b.borde = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.borde:SetAllPoints()
  b.fondo = b:CreateTexture(nil, "BACKGROUND", nil, 2); b.fondo:SetPoint("TOPLEFT", 1, -1); b.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
  b.franja = b:CreateTexture(nil, "ARTWORK", nil, 1); b.franja:SetPoint("TOPLEFT", 1, -1); b.franja:SetPoint("BOTTOMLEFT", 1, 1); b.franja:SetWidth(3)
  b.icono = b:CreateTexture(nil, "ARTWORK", nil, 2); b.icono:SetSize(28, 28); b.icono:SetPoint("LEFT", 8, 0)
  if WowF.marcoRetrato then
    local ok, r = pcall(WowF.marcoRetrato, b, 30)
    if ok and r then b.ret = r; r:SetPoint("LEFT", 7, 0); pcall(function() r:SetFrameLevel((tonumber(b:GetFrameLevel()) or 0) + 1) end) end
  end
  b.nombre = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.nombre:SetPoint("TOPLEFT", 44, -7)
  b.det = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.det:SetPoint("TOPLEFT", 44, -23)
  for _, f in ipairs({ b.nombre, b.det }) do
    if f.SetWordWrap then f:SetWordWrap(false) end
    if f.SetJustifyH then f:SetJustifyH("LEFT") end
  end
  local E = estilo()
  if E then pcall(E.cuerpo, b, b.nombre, 11); pcall(E.sub, b, b.det, 9) end
  b:SetScript("OnEnter", function(self)
    local p = self.paso
    if not GameTooltip or not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.n or "?", 1, 0.82, 0.41, 1, true)
    if p.det and p.det ~= "" then GameTooltip:AddLine(p.det, 0.94, 0.91, 0.85, true) end
    if type(p.exp) == "table" then for _, s in ipairs(p.exp) do GameTooltip:AddLine(s, 0.8, 0.77, 0.7, true) end end
    if p.siguiente and p.hacer then GameTooltip:AddLine(L("Qué hacer ahora: ", "What to do now: ") .. p.hacer, R.AZUL[1], R.AZUL[2], R.AZUL[3], true)
    elseif p.siguiente then GameTooltip:AddLine(L("Es tu siguiente paso.", "This is your next step."), R.AZUL[1], R.AZUL[2], R.AZUL[3], true) end
    if p.ayuda and p.accion then GameTooltip:AddLine(p.ayuda, 0.64, 0.6, 0.55, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetScript("OnClick", function(self) local p = self.paso; if p and p.accion then pcall(p.accion) end end)
  return b
end

-- Una caja del esquema en (x, y) con ancho w y alto 44
function R.caja(p, x, y, w)
  R.nc = R.nc + 1
  local b = R.cajas[R.nc]
  if not b then b = R.nuevaCaja(); R.cajas[R.nc] = b end
  b.paso = p
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", R.padre, "TOPLEFT", x, -y); b:SetSize(w, 44)
  local c = R.COL[p.estado] or R.COL.pendiente
  local borde = p.siguiente and R.AZUL or c.borde
  if b.borde.SetColorTexture then
    b.borde:SetColorTexture(borde[1], borde[2], borde[3], 1)
    b.fondo:SetColorTexture(c.fondo[1], c.fondo[2], c.fondo[3], 0.94)
    b.franja:SetColorTexture(c.borde[1], c.borde[2], c.borde[3], 1)
  end
  -- icono real: retrato del NPC (o del jugador), miniatura de la mazmorra o el icono del paso
  if p.ret and b.ret then
    b.icono:Hide(); b.ret:Show()
    pcall(b.ret.poner, b.ret, p.ret)
  else
    if b.ret then b.ret:Hide() end
    b.icono:Show()
    local ok = false
    if p.mini then
      ok = pcall(b.icono.SetTexture, b.icono, p.mini)
      if ok and b.icono.SetTexCoord then pcall(b.icono.SetTexCoord, b.icono, 0.18, 0.5, 0.05, 0.7) end
    end
    if not ok then
      pcall(b.icono.SetTexture, b.icono, p.icono or R.ICONO_MISION)
      if b.icono.SetTexCoord then pcall(b.icono.SetTexCoord, b.icono, 0.08, 0.92, 0.08, 0.92) end
    end
  end
  b.nombre:SetWidth(w - 50); b.det:SetWidth(w - 50)
  b.nombre:SetText(p.n or "")
  b.det:SetText((R.TXT[p.estado] or "") .. (p.det or "") .. "|r")
  if b.SetAlpha then b:SetAlpha(1) end
  b:Show()
  if p.siguiente then
    R.brillo:ClearAllPoints()
    R.brillo:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3); R.brillo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
    R.brillo:Show()
  end
  table.insert(R.estado.cajas, { n = p.n, det = p.det, estado = p.estado, tipo = p.tipo, siguiente = p.siguiente and true or false })
  return b
end

-- Fila del recuadro "Dentro de la mazmorra": icono pequeno + nombre coloreado, clic = ruta
function R.fila(p, x, y, w)
  R.nf = R.nf + 1
  local f = R.filas[R.nf]
  if not f then
    f = CreateFrame("Button", nil, R.capa)
    pcall(function() f:SetFrameLevel((tonumber(R.capa:GetFrameLevel()) or 0) + 3) end)
    f.marca = f:CreateTexture(nil, "BACKGROUND", nil, 3); f.marca:SetAllPoints(); f.marca:Hide()
    f.icono = f:CreateTexture(nil, "ARTWORK"); f.icono:SetSize(16, 16); f.icono:SetPoint("LEFT", 2, 0)
    f.texto = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.texto:SetPoint("LEFT", 22, 0)
    if f.texto.SetWordWrap then f.texto:SetWordWrap(false) end
    if f.texto.SetJustifyH then f.texto:SetJustifyH("LEFT") end
    local E = estilo()
    if E then pcall(E.cuerpo, f, f.texto, 10) end
    f:SetScript("OnEnter", function(self)
      local q = self.paso
      if not GameTooltip or not q then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(q.n or "?", 1, 0.82, 0.41, 1, true)
      if q.det and q.det ~= "" then GameTooltip:AddLine(q.det, 0.94, 0.91, 0.85, true) end
      if type(q.exp) == "table" then for _, s in ipairs(q.exp) do GameTooltip:AddLine(s, 0.8, 0.77, 0.7, true) end end
      if q.siguiente and q.hacer then GameTooltip:AddLine(L("Qué hacer ahora: ", "What to do now: ") .. q.hacer, R.AZUL[1], R.AZUL[2], R.AZUL[3], true) end
      if q.accion then GameTooltip:AddLine(L("Clic: te llevo (ruta en el mapa).", "Click: I will take you (route on the map)."), 0.64, 0.6, 0.55, true) end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:SetScript("OnClick", function(self) local q = self.paso; if q and q.accion then pcall(q.accion) end end)
    R.filas[R.nf] = f
  end
  f.paso = p
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", R.padre, "TOPLEFT", x, -y); f:SetSize(w, 20)
  local icono = (p.estado == "registro" or p.estado == "hecho") and R.ICONO_ACTIVA or R.ICONO_MISION
  if p.tipo == "aviso" then icono = R.ICONO_MISION end
  pcall(f.icono.SetTexture, f.icono, icono)
  if f.icono.SetDesaturated then pcall(f.icono.SetDesaturated, f.icono, p.estado == "nivel" or p.estado == "pendiente") end
  f.texto:SetWidth(w - 26)
  local extra = ((p.tipo == "dentro" or p.tipo == "aviso") and p.det and p.det ~= "") and ("|cffa39a8c · " .. p.det .. "|r") or ""
  f.texto:SetText((R.TXT[p.estado] or "") .. (p.n or "") .. "|r" .. extra)
  if p.siguiente and f.marca.SetColorTexture then f.marca:SetColorTexture(R.AZUL[1], R.AZUL[2], R.AZUL[3], 0.25); f.marca:Show() else f.marca:Hide() end
  f:Show()
  table.insert(R.estado.cajas, { n = p.n, det = p.det, estado = p.estado, tipo = p.tipo, siguiente = p.siguiente and true or false })
  return f
end

function WowF.diarioRutaSoltar()
  if not R.capa then return end
  for i = 1, #R.cajas do R.cajas[i]:Hide() end
  for i = 1, #R.filas do R.filas[i]:Hide() end
  for i = 1, #R.textos do R.textos[i]:Hide() end
  for _, t in pairs(R.texs) do t:Hide() end
  for _, l in pairs(R.lineas) do if l.Hide then l:Hide() end end
  R.nc, R.nf, R.ntx, R.nt, R.nl = 0, 0, 0, 0, 0
  R.brillo:Hide(); R.barra:Hide(); R.lado:Hide()
end

-- WowF.diarioPintarRuta(contenedor, m, ancho [, x0, y0]) -> y de abajo (en el contenedor, y crece hacia abajo)
function WowF.diarioPintarRuta(contenedor, m, ancho, x0, y0)
  if not contenedor or type(m) ~= "table" then return y0 or 0 end
  R.crear(contenedor)
  WowF.diarioRutaSoltar()
  x0, y0, ancho = x0 or 0, y0 or 0, math.max(200, ancho or 400)
  R.estado = { mazmorra = m.n, cajas = {} }
  local pr = WowF.progresoMazmorra(m)
  R.estado.hechos, R.estado.total = pr.hechos, pr.total
  R.estado.siguiente = pr.siguiente and pr.siguiente.n or nil
  local E = estilo()
  -- Cabecera: "Progreso 3/6" + barra + leyenda
  local y = y0
  local completa = pr.total > 0 and pr.hechos == pr.total
  R.texto(x0, y, 180, L("Progreso ", "Progress ") .. pr.hechos .. "/" .. pr.total, "titulo", 14)
  R.barra:ClearAllPoints(); R.barra:SetPoint("TOPLEFT", R.padre, "TOPLEFT", x0 + 150, -(y + 6))
  local wb = math.max(60, ancho - 150)
  R.barra:SetWidth(wb)
  R.barra:Show()
  pcall(R.barra.poner, R.barra, pr.hechos, pr.total, "verde")
  y = y + 24
  R.estado.hacer = pr.hacer
  if pr.hacer then
    local _, ah = R.texto(x0, y, ancho, "|cff59a6ff" .. L("QUÉ HACER AHORA: ", "WHAT TO DO NOW: ") .. "|r" .. pr.hacer, "cuerpo", 11)
    y = y + ah + 6
  end
  local _, a = R.texto(x0, y, ancho, (completa and (R.TXT.hecho .. L("¡Todo hecho en esta mazmorra! ", "All done in this dungeon! ") .. "|r") or "")
    .. R.TXT.hecho .. L("verde hecho", "green done") .. "|r · " .. R.TXT.registro .. L("amarillo en tu registro", "yellow in your log") .. "|r · "
    .. R.TXT.pendiente .. L("gris pendiente", "grey pending") .. "|r · " .. R.TXT.nivel .. L("rojo falta nivel", "red level missing") .. "|r · "
    .. "|cff59a6ff" .. L("azul: tu siguiente paso", "blue: your next step") .. "|r", "sub", 9)
  y = y + a + 8
  -- 12-oct (Andy: "que la gente entienda como funciona la ruta"): explicacion corta, siempre a la vista
  local _, at = R.texto(x0, y, ancho, L("CÓMO FUNCIONA LA RUTA", "HOW THE ROUTE WORKS"), "etiqueta", 9)
  y = y + at + 3
  local _, ae = R.texto(x0, y, ancho,
    L("1. Sigue las cajas de arriba abajo: primero el nivel, luego las misiones que se piden FUERA (antes de entrar), después la entrada; a la derecha, lo que se hace DENTRO; al final, a quién entregarlas.",
      "1. Follow the boxes from top to bottom: first the level, then the quests picked up OUTSIDE (before going in), then the entrance; on the right, what you do INSIDE; at the end, who to turn them in to.") .. "\n"
    .. L("2. Haz clic en cualquier caja: te pone el alfiler y la ruta en el mapa hasta ese NPC o sitio.",
      "2. Click any box: it sets the pin and the route on the map to that NPC or place.") .. "\n"
    .. L("3. No hay que marcar nada: al aceptar o entregar una misión, la caja cambia de color sola y el azul pasa al siguiente paso.",
      "3. Nothing to tick: when you accept or turn in a quest, the box changes color by itself and the blue moves to the next step."),
    "sub", 9)
  y = y + ae + 12
  -- Filas del esquema (max 2 cajas por fila, para que quepan los nombres); "entrar" + recuadro lateral "Dentro de la mazmorra"
  local filas, lado = {}, {}
  local porFila = {}
  for _, p in ipairs(pr.pasos) do
    if p.tipo == "dentro" or p.lado then table.insert(lado, p)
    else
      local f = p.fila or 9
      if not porFila[f] then porFila[f] = {}; table.insert(filas, f) end
      table.insert(porFila[f], p)
    end
  end
  table.sort(filas)
  local GAPX, GAPY, ALTO = 10, 22, 44
  local anterior -- { salidas = { {x, y} }, hecho = bool }
  local tenue, verde = { 0.42, 0.4, 0.37 }, R.COL.hecho.borde
  local function unir(llegadas, yTop)
    if not anterior or #llegadas == 0 then return end
    local col = anterior.hecho and verde or tenue
    local ym = yTop - GAPY / 2
    local xmin, xmax = math.huge, -math.huge
    for _, s in ipairs(anterior.salidas) do
      R.raya(s[1], s[2], s[1], ym, col, 0.9)
      xmin, xmax = math.min(xmin, s[1]), math.max(xmax, s[1])
    end
    for _, xl in ipairs(llegadas) do
      R.raya(xl, ym, xl, yTop, col, 0.9)
      xmin, xmax = math.min(xmin, xl), math.max(xmax, xl)
    end
    if xmax > xmin then R.raya(xmin, ym, xmax, ym, col, 0.9) end
  end
  for _, f in ipairs(filas) do
    local lista = porFila[f]
    local i = 1
    while i <= #lista do
      local trozo = {}
      for k = i, math.min(#lista, i + 1) do table.insert(trozo, lista[k]) end
      i = i + #trozo
      local llegadas, salidas, todoHecho = {}, {}, true
      local yBajo = y + ALTO
      if f == 4 and trozo[1].tipo == "entrar" then
        -- Entrar a la izquierda y el recuadro "Dentro de la mazmorra" a la derecha, unidos por una raya
        local w1 = math.min(260, math.floor(ancho * 0.42))
        local xl = x0 + w1 + 34
        local wl = x0 + ancho - xl
        local p = trozo[1]
        R.caja(p, x0, y, w1)
        table.insert(llegadas, x0 + w1 / 2); table.insert(salidas, { x0 + w1 / 2, y + ALTO })
        if p.estado ~= "hecho" then todoHecho = false end
        local altoLado = 24 + math.max(1, #lado) * 21 + 6
        R.lado:ClearAllPoints(); R.lado:SetPoint("TOPLEFT", R.padre, "TOPLEFT", xl, -y); R.lado:SetSize(wl, altoLado); R.lado:Show()
        R.texto(xl + 8, y + 6, wl - 16, L("Dentro de la mazmorra", "Inside the dungeon"), "etiqueta", 9)
        local yy = y + 24
        for _, q in ipairs(lado) do
          R.fila(q, xl + 6, yy, wl - 12)
          if q.cuenta and q.estado ~= "hecho" then todoHecho = false end
          yy = yy + 21
        end
        R.raya(x0 + w1, y + ALTO / 2, xl, y + ALTO / 2, (p.estado == "hecho") and verde or tenue, 0.9)
        table.insert(salidas, { xl + wl / 2, y + altoLado })
        yBajo = math.max(y + ALTO, y + altoLado)
      else
        local n = #trozo
        local w = math.min(n == 1 and 380 or 360, math.floor((ancho - (n - 1) * GAPX) / n))
        local total = n * w + (n - 1) * GAPX
        local xi = x0 + math.floor((ancho - total) / 2)
        for k, p in ipairs(trozo) do
          local xx = xi + (k - 1) * (w + GAPX)
          R.caja(p, xx, y, w)
          table.insert(llegadas, xx + w / 2); table.insert(salidas, { xx + w / 2, y + ALTO })
          if p.cuenta and p.estado ~= "hecho" then todoHecho = false end
        end
      end
      unir(llegadas, y)
      anterior = { salidas = salidas, hecho = todoHecho }
      y = yBajo + GAPY
    end
  end
  R.estado.alto = y - y0
  return y
end

-- Para las pruebas: lo que se ve en la pestana Ruta
function WowF.diarioRutaEstado() return R.estado end
function WowF.diarioRutaTexto()
  local t = {}
  for i = 1, R.ntx do local f = R.textos[i]; if f and f.GetText then table.insert(t, f:GetText() or "") end end
  for _, c in ipairs(R.estado.cajas or {}) do table.insert(t, (c.n or "") .. " | " .. (c.det or "")) end
  return table.concat(t, "\n")
end
