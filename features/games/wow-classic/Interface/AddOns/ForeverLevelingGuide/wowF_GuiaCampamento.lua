-- wowF GuiaCampamento: guía de los bufos de campamento de WoW Forever (16-oct).
--   WowF.seccionGuiaCampamento(p, h): 1) qué es el campamento, paso a paso; 2) los mejores bufos para TI (clase, rama, nivel, facción);
--   3) la lista completa con el efecto a TU nivel, quién lo pone y cómo se aprende (VERDE si lo puedes poner tú; si no, "pídeselo a un X";
--   clic = ruta al entrenador); 4) consejos (espera compartida, Legacy, sentarse 60 s); 5) lo que aún no está confirmado.
-- Datos: WowFGuiaCampamento (wowF_GuiaCampamento_Datos.lua, generado por herramientas/generar-guia-campamento.mjs) para la mecánica y el
-- criterio por rol; WowFCampamento (wowF_Campamento_Datos.lua) para los efectos y números de cada objeto. Solo fuentes de WoW Forever.

WowF = WowF or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local G = {}   -- ayudantes (en una tabla para no gastar variables locales)

function G.nivel() local ok, n = pcall(UnitLevel, "player"); n = ok and tonumber(n) or nil; return n or 1 end
function G.fac()
  local ok, f = pcall(UnitFactionGroup, "player")
  if ok and f == "Horde" then return "H" elseif ok and f == "Alliance" then return "A" end
  return nil
end
function G.clase(p)
  local c = p and p.clase
  if not c then local ok, _, tk = pcall(UnitClass, "player"); c = ok and tk or nil end
  return c and tostring(c):upper() or ""
end
function G.nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
function G.sabida(spell)
  if not IsPlayerSpell or not spell then return false end
  local ok, si = pcall(IsPlayerSpell, spell)
  return ok and si == true
end
function G.rango(prof)
  if not WowF.rangoProfesion then return 0 end
  local ok, r = pcall(WowF.rangoProfesion, prof)
  return (ok and tonumber(r)) or 0
end
function G.una(x) return x.una and (NARANJA .. L(" (una sola fuente)", " (single source)") .. "|r") or "" end

-- Objeto de Tier 1 (el que da el bufo base) de una profesión, de tu facción
function G.objeto(nombre, prof)
  if not WowF.campamentoDeProfesion then return nil end
  local ok, r = pcall(WowF.campamentoDeProfesion, prof, 9999)
  if not (ok and r) then return nil end
  for _, o in ipairs(r.ya or {}) do if o.n == nombre then return o end end
  for _, o in ipairs(r.ya or {}) do if o.tier == 1 then return o end end
  return nil
end

-- ¿Ya te pones tú ese bufo con tu clase a tu nivel? (Blessing of Might, Arcane Intellect...)
function G.loDaTuClase(hechizo, clase, N)
  if not hechizo or hechizo == "" then return false end
  local h = WowFHechizos and WowFHechizos[clase] and WowFHechizos[clase][hechizo]
  if type(h) ~= "table" then return false end
  if (tonumber(h[1]) or 99) <= N then return true end
  for i = 2, #h do if G.sabida(h[i]) then return true end end
  return false
end

-- Tu rol para el orden de los bufos (criterio del addon; las guías no dan orden por rol)
function G.rol(p, clase)
  local pesos = (p and p.pesos) or {}
  local rama = tostring((p and p.ramaPesos) or "")
  if (pesos[12] or 0) > 0 or rama:find("Protection") or rama:find("Bear") then return "tanque" end
  if clase == "HUNTER" then return "cazador" end
  if (pesos[41] or 0) >= 1 and (pesos[42] or 0) < 0.5 then return "sanador" end
  if math.max(pesos[45] or 0, pesos[42] or 0, pesos[41] or 0) >= 0.9 then return "lanzador" end
  return "fisico"
end

-- ¿Lo descartas para ti? (devuelve el motivo o nil)
function G.descartar(nombre, b, clase, N, pesos, rol)
  if G.loDaTuClase(b.excluye, clase, N) then
    return L("ya te pones " .. b.excluye .. " y no se suman", "you already cast " .. b.excluye .. " and they do not stack")
  end
  if b.stat == 43 and (clase == "WARRIOR" or clase == "ROGUE") then return L("no usas maná", "you do not use mana") end
  if b.stat == 4 and (pesos[4] or 0) <= 0 and rol ~= "tanque" then return L("tu rama no usa Strength", "your spec does not use Strength") end
  if b.stat == "rested" and N >= 60 then return L("ya no subes de nivel", "you no longer level up") end
  return nil
end

-- Entrenador verificado de tu facción (el más cercano), como en wowF_Consumibles.lua
function G.entrenador(prof, r)
  local lista, fac = {}, G.fac()
  for _, e in ipairs((WowFDatos and WowFDatos.entrenadores and WowFDatos.entrenadores[prof]) or {}) do
    if (e[5] == fac or e[5] == "N") and not (WowF.esAproximado and WowF.esAproximado(e)) and (tonumber(e[6]) or 0) >= r then
      lista[#lista + 1] = { m = e[2], x = e[3], y = e[4], e = e }
    end
  end
  if #lista == 0 then return nil end
  local c = lista[1]
  if WowF._bisMasCerca then local ok, r2 = pcall(WowF._bisMasCerca, lista); if ok and r2 then c = r2 end end
  return c.e
end
function G.irEntrenador(prof, r)
  local e = G.entrenador(prof, r)
  local nombre = G.nombreProf(prof)
  if not e then
    if print then print(Y(NARANJA .. L("Aún no hay datos de WoW Forever del entrenador de " .. nombre .. "; pendiente de actualizar.",
      "No WoW Forever data yet for the " .. nombre .. " trainer; pending update.") .. "|r")) end
    return false
  end
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  local destino = { m = e[2], x = e[3], y = e[4], n = e[1], z = e[7], lugar = true, final = { titulo = e[1], corto = e[1], detalle = "",
    ventana = ORO .. L("Entrenador de ", "") .. nombre .. L("", " trainer") .. "|r",
    texto = Y(L("Habla con " .. e[1] .. " y entrena " .. nombre, "Talk to " .. e[1] .. " and train " .. nombre)),
    llegada = Y(L("Habla con " .. e[1] .. " y aprende el objeto de campamento de " .. nombre .. ".", "Talk to " .. e[1] .. " and learn the " .. nombre .. " camp item.")), npc = e[1] } }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = e[1], sub = ORO .. Y(L("Entrenador de ", "") .. nombre .. L("", " trainer")) .. "|r" }) end
  if WowF.viajeA then local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }); if ok and hecho then return true end end
  return WowF.marcarEntrenador and WowF.marcarEntrenador(e, nombre) ~= nil
end

-- Una fila de bufo: efecto a tu nivel + quién lo pone + si lo puedes poner tú
function G.fila(h, nombre, b, N, porque)
  local o = G.objeto(nombre, b.prof)
  local prof = G.nombreProf(b.prof)
  local efecto = o and WowF.campamentoTexto and WowF.campamentoTexto(o, N) or L(b.es, b.en)
  local mio = o and G.rango(b.prof) >= (o.rango or 0) and (o.rango or 0) > 0
  local sabe = o and G.sabida(o.receta)
  local estado
  if mio and sabe then estado = VERDE .. L("Lo puedes poner tú.", "You can place it.") .. "|r"
  elseif mio then estado = VERDE .. L("Tienes el rango: apréndelo con el entrenador de " .. prof .. " (clic = ruta).", "You have the skill: learn it from the " .. prof .. " trainer (click = route).") .. "|r"
  else estado = NARANJA .. L("Pídeselo a alguien con " .. prof .. " (rango " .. ((o and o.rango) or "?") .. ").", "Ask someone with " .. prof .. " (skill " .. ((o and o.rango) or "?") .. ").") .. "|r" end
  local como = o and WowF.campamentoComo and WowF.campamentoComo(o) or ""
  local nombreColor = (mio and sabe) and VERDE or BLANCO
  h.item({ texto = Y(nombreColor .. nombre .. "|r" .. GRIS .. " - " .. prof .. "|r"),
    sub = Y((porque and (CELESTE .. porque .. "|r\n") or "") .. BLANCO .. efecto .. "|r\n" .. estado .. (como ~= "" and ("\n" .. GRIS .. como .. "|r") or "")),
    icono = h.icono and o and (o.objeto or 0) > 0 and h.icono(nil, o.objeto) or nil, objeto = o and (o.objeto or 0) > 0 and o.objeto or nil,
    sangria = 12, chico = true,
    accion = (o and (o.bp or 0) == 0) and function() return G.irEntrenador(b.prof, o.rango or 0) end or nil })
end

function WowF.seccionGuiaCampamento(p, h)
  local d = WowFGuiaCampamento
  h.cab(ORO .. L("Guía del campamento: los mejores bufos", "Camp guide: the best buffs") .. "|r")
  if not (d and WowFCampamento) then
    h.nota(NARANJA .. L("Aún no hay datos de WoW Forever del campamento; pendiente de actualizar.", "No WoW Forever camp data yet; pending update.") .. "|r")
    return
  end
  p = p or (WowF.planActual and WowF.planActual()) or {}
  local N, clase = G.nivel(), G.clase(p)
  local pesos = p.pesos or {}
  local rol = G.rol(p, clase)
  local mec = {}
  for _, m in ipairs(d.mecanica) do mec[m.clave] = m end

  -- 1) Qué es, paso a paso
  h.nota(Y(ORO .. L("Cómo funciona", "How it works") .. "|r"))
  for i, k in ipairs({ "inicio", "fogata", "colocar", "sentarse", "duracion", "quien" }) do
    local m = mec[k]
    if m then h.nota(Y(BLANCO .. i .. ". " .. L(m.es, m.en) .. "|r" .. G.una(m))) end
  end

  -- 2) Los mejores bufos para ti
  h.separador()
  h.nota(Y(ORO .. L("Los mejores bufos para ti", "The best buffs for you") .. "|r" .. GRIS .. " (" .. tostring(p.ramaPesos or clase) .. L(", nivel ", ", level ") .. N .. ")|r"))
  local orden, quitados, puestos = {}, {}, 0
  if N < 60 then orden[1] = "Camp Tent" end
  for _, n in ipairs(d.roles[rol] or {}) do orden[#orden + 1] = n end
  for _, n in ipairs(orden) do
    local b = d.buffs[n]
    local motivo = b and G.descartar(n, b, clase, N, pesos, rol)
    if b and motivo then quitados[#quitados + 1] = n .. " (" .. motivo .. ")"
    elseif b and puestos < 4 then puestos = puestos + 1; G.fila(h, n, b, N, L(b.es, b.en)) end
  end
  if #quitados > 0 then h.nota(Y(GRIS .. L("Fuera de tu lista: ", "Left out: ") .. table.concat(quitados, "; ") .. ".|r")) end
  local pvp = {}
  for _, n in ipairs(d.roles.pvp or {}) do
    local b = d.buffs[n]
    if b and not G.descartar(n, b, clase, N, pesos, rol) then pvp[#pvp + 1] = n end
  end
  if #pvp > 0 then h.nota(Y(CELESTE .. L("Para PvP: ", "For PvP: ") .. table.concat(pvp, " > ") .. "|r")) end
  h.nota(Y(GRIS .. L(d.criterio.es, d.criterio.en) .. "|r"))

  -- 3) Lista completa
  h.separador()
  h.nota(Y(ORO .. L("Todos los bufos (valores a tu nivel)", "All buffs (values at your level)") .. "|r"))
  local nombres = {}
  for n in pairs(d.buffs) do nombres[#nombres + 1] = n end
  table.sort(nombres, function(a, b) return (a == "Basic Campfire Kit") or (b ~= "Basic Campfire Kit" and a < b) end)
  for _, n in ipairs(nombres) do
    local b = d.buffs[n]
    if G.objeto(n, b.prof) or b.prof ~= 197 then G.fila(h, n, b, N, nil) end
  end

  -- 4) Consejos
  h.separador()
  h.nota(Y(ORO .. L("Consejos", "Tips") .. "|r"))
  local espera, notaLegacy = 60, nil
  if WowF.esperaCampamento then local ok, a, b = pcall(WowF.esperaCampamento, 60); if ok then espera, notaLegacy = a or 60, b end end
  h.nota(Y(BLANCO .. L("Tu espera entre objetos de campamento: ", "Your cooldown between camp items: ") .. espera .. " min|r" .. (notaLegacy or "")))
  for _, k in ipairs({ "nosuma", "reemplazar", "objetos15", "lugar", "comerciar", "esperafogata" }) do
    local m = mec[k]
    if m then h.nota(Y(BLANCO .. "- " .. L(m.es, m.en) .. "|r" .. G.una(m))) end
  end
  for _, l in ipairs(d.legacy or {}) do
    local tiene = false
    if WowF.legacyValor then local ok, v = pcall(WowF.legacyValor, l.id); tiene = ok and (tonumber(v) or 0) > 0 end
    h.nota(Y((tiene and VERDE or GRIS) .. "Legacy " .. l.n .. ": " .. L(l.es, l.en) .. (tiene and L(" (lo tienes)", " (you have it)") or "") .. "|r" .. G.una(l)))
  end

  -- 5) Sin confirmar
  h.separador()
  h.nota(Y(NARANJA .. L("Aún no hay datos de WoW Forever; pendiente de actualizar:", "No WoW Forever data yet; pending update:") .. "|r"))
  for _, s in ipairs(d.sinDatos or {}) do h.nota(Y(GRIS .. "- " .. L(s.es, s.en) .. "|r")) end
  h.nota(Y(GRIS .. L("Fuente: ", "Source: ") .. "Icy Veins (wow-forever/camping)" .. L(", Wowhead /forever y las tablas del cliente de la beta ", ", Wowhead /forever and the beta client tables ") .. tostring(d.build) .. ".|r"))
end
