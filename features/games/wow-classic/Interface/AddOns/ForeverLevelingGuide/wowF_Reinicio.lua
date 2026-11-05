-- wowF Reinicio: reiniciar talentos (empezar de cero). Cuanto cuesta segun las veces que lo llevas y el entrenador
-- de tu clase mas cercano, con alfiler y el mapa abierto. El precio real lo lee del entrenador (CONFIRM_TALENT_WIPE)
-- y lo guarda; mientras no lo hayas visto, solo dice "desde 1 plata" (nota de parche de Blizzard del 8-oct para Forever:
-- sube si reinicias seguido y baja un paso por hora). 9-oct: fuera la tabla de precios de Classic (regla de Andy: cero datos de Classic).
-- Si Blizzard publica otro precio para Forever, cambiar PRECIO_DESDE (y EN_BETA) aqui.
-- /wowf reiniciar: costo, veces y alfiler al entrenador mas cercano.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff"

local EN_BETA = true
local PRECIO_DESDE = 100 -- cobre: 1 plata, precio minimo segun la nota de parche de Blizzard (8-oct)
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end

local function clave()
  local nombre = UnitName("player") or "?"
  local reino = (GetRealmName and GetRealmName()) or ""
  return reino ~= "" and (nombre .. "-" .. reino) or nombre
end
local function datos()
  WowFExportarDB.reinicio = WowFExportarDB.reinicio or {}
  local k = clave()
  WowFExportarDB.reinicio[k] = WowFExportarDB.reinicio[k] or { veces = 0 }
  return WowFExportarDB.reinicio[k]
end
-- Numero seguro (la beta puede devolver valores secretos)
local function numero(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return tonumber(v)
end

-- "1 oro 5 plata" a partir de cobre
function WowF.dinero(cobre)
  cobre = math.floor(cobre or 0)
  local o, p, c = math.floor(cobre / 10000), math.floor(cobre / 100) % 100, cobre % 100
  local t = {}
  if o > 0 then table.insert(t, o .. " oro") end
  if p > 0 then table.insert(t, p .. " plata") end
  if c > 0 or #t == 0 then table.insert(t, c .. " cobre") end
  return table.concat(t, " ")
end

-- { veces, proximo (cobre), visto (true si lo dijo el entrenador), desde (true = solo el minimo de Blizzard, no el precio exacto) }
function WowF.costoReinicio()
  local d = datos()
  local proximo, visto = PRECIO_DESDE, false
  if d.visto and d.vistoVez == d.veces + 1 then proximo, visto = d.visto, true end
  return { veces = d.veces, proximo = proximo, visto = visto, desde = not visto, beta = EN_BETA }
end

-- Entrenador de tu clase mas cercano: { nombre, mapa, x, y, fac, 0, zona }
local CAPITALES = { H = { 1454, 1456, 1458 }, A = { 1453, 1455, 1457 } }
function WowF.entrenadorClaseCercano()
  local _, token = UnitClass("player")
  local lista = WowFDatos and WowFDatos.entrenadoresClase and WowFDatos.entrenadoresClase[token or ""]
  if not lista then return nil end
  local fac = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  local mios = {}
  for _, e in ipairs(lista) do if (e[5] == fac or e[5] == "N") and not (WowF.esAproximado and WowF.esAproximado(e)) then table.insert(mios, e) end end -- 9-oct: sin posiciones de Classic
  if #mios == 0 then return nil end
  local mapa = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  -- 1. Por distancia real en el mismo continente (si el cliente lo permite)
  local mejor, dist = nil, nil
  pcall(function()
    local pos = mapa and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapa, "player")
    if not pos or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local cont, yo = C_Map.GetWorldPosFromMapPos(mapa, pos)
    if not yo then return end
    local yx, yy = yo:GetXY()
    for _, e in ipairs(mios) do
      local c2, p2 = C_Map.GetWorldPosFromMapPos(e[2], CreateVector2D(e[3] / 100, e[4] / 100))
      if p2 and c2 == cont then
        local ex, ey = p2:GetXY()
        local d = (ex - yx) ^ 2 + (ey - yy) ^ 2
        if not dist or d < dist then mejor, dist = e, d end
      end
    end
  end)
  if mejor then return mejor end
  -- 2. En el mapa donde estas
  for _, e in ipairs(mios) do if e[2] == mapa then return e end end
  -- 3. En una capital de tu faccion
  for _, m in ipairs(CAPITALES[fac]) do for _, e in ipairs(mios) do if e[2] == m then return e end end end
  return mios[1]
end

-- Alfiler al entrenador y abre el mapa en ese sitio
function WowF.irAReiniciar() return WowF.irAlEntrenador((WowF.enIngles and WowF.enIngles()) and "reset your talents" or "reiniciar talentos") end
-- Alfiler al entrenador de clase mas cercano; motivo = para que vas (sale en el alfiler)
function WowF.irAlEntrenador(motivo)
  local e = WowF.entrenadorClaseCercano()
  if not e then print(WowF.T(AZUL .. "no tengo la posicion de los entrenadores de tu clase; ve al de tu capital.")); return nil end
  local clase = (UnitClass and UnitClass("player")) or "tu clase"
  if WowF.marcar then WowF.marcar({ m = e[2], x = e[3], y = e[4], n = e[1] .. " (entrenador de " .. clase .. ": " .. (motivo or "entrenar") .. ")", z = e[7], lugar = true }) end
  if WorldMapFrame and not WowF.interfazMando() then -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
    pcall(function()
      if not WorldMapFrame:IsShown() then if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end end
      if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(e[2]) end
    end)
  end
  return e
end

-- El entrenador dice el precio real al abrir el dialogo; al quedar todos los puntos libres, cuenta una vez mas
local vigia = CreateFrame("Frame")
for _, ev in ipairs({ "CONFIRM_TALENT_WIPE", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(vigia.RegisterEvent, vigia, ev) end
vigia:SetScript("OnEvent", function(_, evento, a1)
  local d = datos()
  if evento == "CONFIRM_TALENT_WIPE" then
    local cobre = numero(a1)
    if cobre then
      d.visto, d.vistoVez, d.pendiente = cobre, d.veces + 1, true
      print(WowF.T(AZUL .. "reiniciar talentos te cuesta " .. ORO .. WowF.dinero(cobre) .. "|r (seria tu vez " .. (d.veces + 1) .. ")."))
    end
    return
  end
  if not d.pendiente then return end
  local libres = numero(UnitCharacterPoints and UnitCharacterPoints("player"))
  local nivel = numero(UnitLevel and UnitLevel("player")) or 0
  -- 12-oct (Legacy "Talented"): con puntos extra, "libres >= nivel - 9" no prueba el reinicio; si el cliente dice los puntos
  -- puestos (WowF.puntosTalento), reiniciado = 0 puestos y alguno libre
  local r = WowF.puntosTalento and WowF.puntosTalento()
  local reiniciado
  if r and r.seguro then reiniciado = r.puestos == 0 and (r.sinGastar or 0) > 0
  else reiniciado = libres and nivel >= 10 and libres >= nivel - 9 end
  if reiniciado then
    d.veces, d.pendiente = d.veces + 1, nil
    print(WowF.T(AZUL .. "talentos reiniciados (vez " .. d.veces .. "). Reparte los puntos: el libro (/wowf plan talentos) te dice el orden."))
  end
end)
-- Para las pruebas
WowF.reinicioEvento = function(ev, a1) vigia:GetScript("OnEvent")(vigia, ev, a1) end

local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
  if orden == "reiniciar" or orden == "reinicio" or orden == "respec" or orden == "reset" then
    local c = WowF.costoReinicio()
    if c.visto then
      print(WowF.yaTraducido(AZUL .. L("reiniciar talentos: lo llevas " .. c.veces .. (c.veces == 1 and " vez" or " veces") .. "; el proximo cuesta " .. ORO .. WowF.dinero(c.proximo) .. "|r (lo dijo el entrenador).",
        "reset talents: done " .. c.veces .. (c.veces == 1 and " time" or " times") .. "; the next one costs " .. ORO .. WowF.dinero(c.proximo) .. "|r (the trainer said so).")))
    else
      print(WowF.yaTraducido(AZUL .. L("reiniciar talentos: lo llevas " .. c.veces .. (c.veces == 1 and " vez" or " veces") .. "; cuesta desde " .. ORO .. "1 plata|r (Blizzard, 8-oct) y sube si reinicias seguido. El precio exacto te lo dice el entrenador.",
        "reset talents: done " .. c.veces .. (c.veces == 1 and " time" or " times") .. "; it costs from " .. ORO .. "1 silver|r (Blizzard, Oct 8) and goes up if you reset often. The trainer tells you the exact price.")))
    end
    local e = WowF.irAReiniciar()
    if e then print(WowF.T(AZUL .. "el entrenador de tu clase mas cercano: " .. BLANCO .. e[1] .. "|r" .. GRIS .. " (" .. e[7] .. " " .. e[3] .. ", " .. e[4] .. ")|r. Te puse el alfiler.")) end
    return
  end
  if anterior then anterior(mensaje) end
end
