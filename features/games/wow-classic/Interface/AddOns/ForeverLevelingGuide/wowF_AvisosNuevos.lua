-- Forever Leveling Guide: avisos de lo NUEVO que ya puedes hacer (pedido de Andy, 4-oct).
--   1. Al subir de nivel (wowF_Panel.lua alSubir pide WowF.lineasNuevasNivel): hechizos nuevos de tu entrenador de clase y
--      piezas que te fabricas que VALEN LA PENA a ese nivel (WowF.valeLaPena del Libro).
--   2. Al subir de rango en una profesion (SKILL_LINES_CHANGED): "Ya puedes fabricarte X" cuando llegas al rango de una pieza
--      que vale la pena para tu nivel. Una vez por pieza y personaje (WowFExportarDB.avisosFab).
-- Solo se dice lo que sale de los datos (WowFHechizos, piezas del plan): nada inventado.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
-- 11-oct (hibrido): colores de WowF.estilo (oro viejo, verde suave, gris tenue, blanco hueso); el aviso sale en el cartel del panel
local E = WowF.estilo
local ORO = E and E.cod.oro or "|cffd8b468"
local VERDE = "|cff9ccc65"
local GRIS = E and E.cod.tenue or "|cffa39a8c"
local BLANCO = E and E.cod.texto or "|cffefe7da"

local function claseJugador() if not UnitClass then return nil end; local _, t = UnitClass("player"); return t end
local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end

-- Hechizos de tu clase que se aprenden justo a este nivel (los talentos no: esos van en la pestana Talentos)
function WowF.hechizosNuevos(nivel)
  local clase = claseJugador()
  local t = WowFHechizos and WowFHechizos[clase or ""]
  local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[clase or ""]
  local lista = {}
  for nombre, h in pairs(t or {}) do
    -- 15-oct: fuera los de otra raza (WoW Forever: Starshards solo Night Elf, Desperate Prayer solo Dwarf...)
    if h[1] == nivel and not (c and c.talentos and c.talentos[nombre]) and not (WowF.hechizoDeOtraRaza and WowF.hechizoDeOtraRaza(nombre, clase)) then
      local n = nombre
      if h[2] and GetSpellInfo then local ok, r = pcall(GetSpellInfo, h[2]); if ok and type(r) == "string" and r ~= "" then n = r end end
      table.insert(lista, n)
    end
  end
  table.sort(lista)
  return lista
end

-- "Copper Chain Vest (Chest, Mail) · Blacksmithing 30 · Objeto: Plans..." -> nombre, id de la profesion, rango, origen
local function datosPieza(e)
  local partes = {}
  for p in (tostring(e[3]) .. " \194\183 "):gmatch("(.-) \194\183 ") do table.insert(partes, p) end
  local nombre = (partes[1] or ""):match("^(.-) %(") or partes[1] or "?"
  local prof, rango = (partes[2] or ""):match("^(.-) (%d+)")
  local id
  for i, n in pairs(WowFDatos and WowFDatos.prof or {}) do if n == prof then id = i end end
  return nombre, id, tonumber(rango), prof, partes[3]
end
local function laTengo(i)
  if not i then return false end
  if IsEquippedItem and IsEquippedItem(i) then return true end
  return GetItemCount and (GetItemCount(i, true) or 0) > 0 or false
end
local function valeLaPena(e)
  if not WowF.valeLaPena then return false end
  if WowF.mejorasDe and not WowF.mejorasDe("fabricar") then return false end -- 8-oct: fabricadas apagadas en Ajustes
  local ok, v = pcall(WowF.valeLaPena, e)
  return ok and v == "si"
end
local function piezas(p)
  local t = {}
  for _, e in ipairs(p and p.eventos or {}) do if e[2] == "equipo" then table.insert(t, e) end end
  return t
end

-- Lineas para el aviso de subir de nivel (ya en su idioma)
function WowF.lineasNuevasNivel(p, nivel)
  local l = {}
  local h = WowF.hechizosNuevos(nivel)
  if #h > 0 then
    local nombres = {}
    for i = 1, math.min(3, #h) do table.insert(nombres, h[i]) end
    local mas = #h > 3 and L(" y " .. (#h - 3) .. " mas", " and " .. (#h - 3) .. " more") or ""
    table.insert(l, VERDE .. L("Hechizo nuevo en tu entrenador de clase: ", "New spell at your class trainer: ") .. "|r" .. BLANCO .. table.concat(nombres, ", ") .. mas .. "|r")
    if WowF.lineaCostoEntrenar then local ok, x = pcall(WowF.lineaCostoEntrenar, nivel, h); if ok and x then table.insert(l, x) end end
  else
    -- 15-oct: niveles con solo rangos nuevos (sin hechizo nuevo) tambien dicen que hay que entrenar y cuanto cuesta
    local ok, r = pcall(function() return WowF.costosDelNivel and WowF.costosDelNivel(nivel) end)
    if ok and r and #r.lista > 0 then
      local nombres = {}
      for i = 1, math.min(3, #r.lista) do
        local e = r.lista[i]
        local n = e.nombre
        if GetSpellInfo then local okN, s = pcall(GetSpellInfo, e.id); if okN and type(s) == "string" and s ~= "" then n = s end end
        table.insert(nombres, n .. ((e.rango or 0) > 0 and L(" (rango " .. e.rango .. ")", " (rank " .. e.rango .. ")") or ""))
      end
      local mas = #r.lista > 3 and L(" y " .. (#r.lista - 3) .. " mas", " and " .. (#r.lista - 3) .. " more") or ""
      table.insert(l, VERDE .. L("Rango nuevo en tu entrenador de clase: ", "New rank at your class trainer: ") .. "|r" .. BLANCO .. table.concat(nombres, ", ") .. mas .. "|r")
      if WowF.lineaCostoEntrenar then local okC, x = pcall(WowF.lineaCostoEntrenar, nivel, {}); if okC and x then table.insert(l, x) end end
    end
  end
  for _, e in ipairs(piezas(p)) do
    if e[1] == nivel and not laTengo(e.i) and valeLaPena(e) then
      local nombre, id, rango, prof = datosPieza(e)
      local tengo = id and WowF.rangoProfesion and WowF.rangoProfesion(id)
      if rango and tengo and tengo >= rango then
        table.insert(l, VERDE .. L("Ya puedes fabricarte: ", "You can now craft: ") .. "|r" .. BLANCO .. nombre .. "|r" .. GRIS .. " (" .. prof .. " " .. rango .. L(", vale la pena)", ", worth it)") .. "|r")
      elseif rango then
        table.insert(l, ORO .. L("Pieza para tu nivel: ", "Gear for your level: ") .. "|r" .. BLANCO .. nombre .. "|r" .. GRIS .. L(" (te falta " .. prof .. " " .. rango .. (tengo and ", tienes " .. tengo or "") .. ")", " (you need " .. prof .. " " .. rango .. (tengo and ", you have " .. tengo or "") .. ")") .. "|r")
      end
    end
  end
  for i, s in ipairs(l) do l[i] = WowF.yaTraducido and WowF.yaTraducido(s) or s end
  return l
end

-- Subir de rango en una profesion: piezas que vale la pena fabricarse YA (las puedes llevar y te duran)
local rangoVisto = {}
function WowF.revisarFabricarNuevo()
  if not WowF.armarPlan or not WowF.rangoProfesion or not WowF.avisar then return end
  local ok, p = pcall(WowF.armarPlan)
  if not (ok and p) then return end
  local nivel = nivelPj()
  WowFExportarDB.avisosFab = WowFExportarDB.avisosFab or {}
  local vistos = WowFExportarDB.avisosFab[clavePj()] or {}
  WowFExportarDB.avisosFab[clavePj()] = vistos
  local nuevas, ahora = {}, {}
  for _, e in ipairs(piezas(p)) do
    local nombre, id, rango, prof, origen = datosPieza(e)
    if id and rango then
      local r = WowF.rangoProfesion(id)
      if r then
        ahora[id] = r
        local antes = rangoVisto[id]
        -- Solo al CRUZAR el rango en esta sesion (la primera lectura solo apunta: no avisa de lo que ya tenias)
        if antes and antes < rango and r >= rango and e[1] <= nivel and (e.hasta or 60) > nivel + 2
          and not vistos[e.i or nombre] and not laTengo(e.i) and valeLaPena(e) then
          vistos[e.i or nombre] = true
          table.insert(nuevas, { nombre = nombre, prof = prof, rango = rango, origen = origen })
        end
      end
    end
  end
  for id, r in pairs(ahora) do rangoVisto[id] = r end
  if #nuevas == 0 then return end
  local l = {}
  for i = 1, math.min(3, #nuevas) do
    local n = nuevas[i]
    table.insert(l, BLANCO .. n.nombre .. "|r" .. GRIS .. " (" .. n.prof .. " " .. n.rango .. ")" .. (n.origen and (" - " .. WowF.T(n.origen)) or "") .. "|r")
  end
  WowF.avisar(WowF.yaTraducido(L("¡Ya puedes fabricarte algo que te sirve!", "You can now craft something useful!")),
    WowF.yaTraducido(table.concat(l, "\n")), nil, 9, "Equipo")
  return nuevas
end
WowF._olvidarRangos = function() rangoVisto = {} end -- para las pruebas

-- 5-oct (revision): TRADE_SKILL_LIST_UPDATE llega muchas veces seguidas con la ventana de la profesion abierta: se agrupa
-- (0,5 s) y solo se revisa si cambio el rango o el numero de recetas (WowF.firmaProfesiones, wowF_ProfObjetivo.lua)
local firmaVista
local function firma()
  if not WowF.firmaProfesiones then return nil end
  local ok, f = pcall(WowF.firmaProfesiones)
  return ok and f or nil
end
local function revisarTodo()
  pcall(WowF.revisarFabricarNuevo)
  if WowF.revisarObjetivoNuevo then pcall(WowF.revisarObjetivoNuevo) end
end
local revisarVentana = (WowF.agrupar or function(fn) return fn end)(function()
  local f = firma()
  if f and f == firmaVista then return end
  firmaVista = f
  revisarTodo()
end, 0.5)
local vigia = CreateFrame("Frame")
for _, ev in ipairs({ "SKILL_LINES_CHANGED", "TRADE_SKILL_LIST_UPDATE", "PLAYER_LEVEL_UP" }) do pcall(vigia.RegisterEvent, vigia, ev) end
vigia:SetScript("OnEvent", function(_, ev)
  if ev == "TRADE_SKILL_LIST_UPDATE" then revisarVentana(); return end
  if ev == "SKILL_LINES_CHANGED" then firmaVista = firma() end
  if ev ~= "PLAYER_LEVEL_UP" then pcall(WowF.revisarFabricarNuevo) end
  -- 5-oct: "Nuevo para vender: X" / "Nuevo para PvP: X", una vez por receta (wowF_ProfObjetivo.lua); al subir, un segundo despues (nivel ya al dia)
  if WowF.revisarObjetivoNuevo then
    if ev == "PLAYER_LEVEL_UP" and C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(WowF.revisarObjetivoNuevo) end)
    else pcall(WowF.revisarObjetivoNuevo) end
  end
end)
