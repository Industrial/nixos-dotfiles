-- wowF Cajas: guia de las Waylaid Crates de Merchant's Favor (8-oct).
--   * Donde caen: de bichos del mundo (Wowhead /forever, "dropped-by"), con el area mas cercana y densa de TU nivel y TU faccion
--     (circulo dorado en el mapa + alfiler, con WowFMobs.areas) y las zonas/mazmorras donde mas se han visto.
--   * Que caja te conviene segun TUS profesiones (recoleccion/fabricacion) y tu nivel, con los lotes que pide cada una y cuanto
--     tienes en las bolsas (GetItemCount); cajas, cajas selladas, Waylaid Crate sin abrir y Shipping Label que llevas.
--   * Donde se entregan: el NPC de tu faccion (WowF.irEntregaFavor de wowF_Favor.lua: ruta paso a paso y alfiler).
--   * /wowf cajas | crates [mapa|map | entrega|turnin]. En el Libro va debajo de Merchant's Favor (pestana Profesiones).
-- Datos: WowFCajas (wowF_Cajas_Datos.lua, generado por herramientas/generar-cajas.mjs) + WowFFavor.cajas (lotes). Nada de la otra
-- faccion; lo que la fuente no confirma se avisa "sin confirmar, se actualizará en próximas actualizaciones".

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local function D() return WowFCajas end
local function F() return WowFFavor end
local function lado()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return "H" elseif f == "Alliance" then return "A" end
  return nil
end
local function fac() local l = lado(); return l == "H" and 2 or (l == "A" and 1 or 0) end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function tengo(id) local ok, n = pcall(GetItemCount, id, true); return (ok and tonumber(n)) or 0 end
local function sinConfirmar() return L("sin confirmar, se actualizará en próximas actualizaciones", "unconfirmed, it will be updated in future updates") end
local function hecha(q)
  if not q or q == 0 or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return false end
  local ok, s = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
  return ok and s == true
end
-- 3568 -> "3.600" / "3,600" (redondeado: son muestras de Wowhead)
local function cifra(n)
  n = tonumber(n) or 0
  if n >= 1000 then n = math.floor(n / 100 + 0.5) * 100 end
  local s = tostring(math.floor(n))
  local sep = L(".", ",")
  local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return r
end
local function zonaPermitida(m, f)
  if WowF._zonaPermitidaMobs then return WowF._zonaPermitidaMobs(m, f) end
  return true
end
local function nombreCaja(c) return c[1] .. " " .. c[2] end
local RANGOS = { "Apprentice", "Journeyman", "Expert", "Artisan" }

-- Tipos de caja que llenas con lo que sacan tus profesiones (Textiles: cualquiera, tela de humanoides)
local TIPOS = {
  [182] = { "Herbs", "Earthly Herbs", "Flowering Herbs" }, -- Herbalism
  [186] = { "Ore", "Ingots" },                             -- Mining (Smelting hace las barras)
  [393] = { "Textiles" },                                  -- Skinning (Light/Medium Leather)
  [333] = { "Curiosities" },                               -- Enchanting (polvos, esencias, fragmentos)
  [197] = { "Fabrics" },                                   -- Tailoring (Bolt of ...)
  [165] = { "Fabrics" },                                   -- Leatherworking (Cured ... Hide)
  [164] = { "Ingots" },                                    -- Blacksmithing
  [202] = { "Parts" },                                     -- Engineering
}
local NOMBRE_PROF = { [182] = "Herbalism", [186] = "Mining", [393] = "Skinning", [333] = "Enchanting", [197] = "Tailoring", [165] = "Leatherworking", [164] = "Blacksmithing", [202] = "Engineering" }

-- Tus profesiones (y las del plan) que llenan cajas: { { id, tipos, delPlan } }
local function profesionesCaja()
  local res, visto = {}, {}
  local ok, lista = pcall(function() return WowF.profesiones and WowF.profesiones() end)
  for _, p in ipairs((ok and lista) or {}) do
    if TIPOS[p.id] and not visto[p.id] then visto[p.id] = true; table.insert(res, { id = p.id, tipos = TIPOS[p.id], rango = p.rango }) end
  end
  local ok2, plan = pcall(function() return WowF.armarPlan and WowF.armarPlan() end)
  for _, id in ipairs((ok2 and plan and plan.ids) or {}) do
    if TIPOS[id] and not visto[id] then visto[id] = true; table.insert(res, { id = id, tipos = TIPOS[id], delPlan = true }) end
  end
  return res
end
WowF.cajasProfesiones = profesionesCaja

-- Rangos de caja que caen a tu nivel (bichos de tu nivel +-) y el proximo
function WowF.cajasRangos(N)
  N = N or nivelPj()
  local d = D()
  local ahora, proximo = {}, nil
  for _, r in ipairs(RANGOS) do
    local x = d and d.rangos and d.rangos[r]
    if x then
      if x[1] <= N + 2 and x[2] >= N - 8 then table.insert(ahora, { rango = r, min = x[1], max = x[2], cada = x[3], vistas = x[4] })
      elseif x[1] > N + 2 and not proximo then proximo = { rango = r, min = x[1], max = x[2], cada = x[3], vistas = x[4] } end
    end
  end
  -- por debajo de todo (nivel bajo): el primero es el proximo
  return ahora, proximo
end

-- Nivel que pide la caja para usarla (WowFFavor.cajas[id][4]); por rango
local function nivelRango(r)
  local f = F()
  for _, c in pairs((f and f.cajas) or {}) do if c[1] == r then return c[4] end end
  return nil
end

-- Lotes de una caja con lo que tienes: texto, hayLoteCompleto
local function lotes(c)
  local t, listo = {}, false
  for _, lote in ipairs(c[5] or {}) do
    local n = tengo(lote[1])
    local falta = lote[2] - n
    if falta <= 0 then listo = true end
    table.insert(t, (falta <= 0 and VERDE or GRIS) .. lote[2] .. " x " .. lote[3] .. "  (" .. L("tienes ", "you have ") .. n
      .. (falta > 0 and (L(", te faltan ", ", you need ") .. falta .. L("", " more")) or L(": LISTO", ": READY")) .. ")|r")
  end
  return table.concat(t, "\n"), listo
end
WowF.cajasLotes = lotes

-- Cajas recomendadas: { { id, c (WowFFavor.cajas), prof, listo } } de los rangos que caen a tu nivel (o el primero si aun no hay)
function WowF.cajasRecomendadas(N)
  N = N or nivelPj()
  local f = F()
  local res = {}
  if not f or not f.cajas then return res end
  local ahora = WowF.cajasRangos(N)
  local rangos = {}
  for _, x in ipairs(ahora) do rangos[x.rango] = true end
  if not next(rangos) then rangos.Apprentice = true end
  local profs = profesionesCaja()
  local quiere = {}
  for _, p in ipairs(profs) do for _, t in ipairs(p.tipos) do quiere[t] = quiere[t] or p end end
  if not next(quiere) then quiere.Textiles = { id = 0 } end -- sin profesiones: tela de humanoides
  local ids = {}
  for id in pairs(f.cajas) do table.insert(ids, id) end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local c = f.cajas[id]
    if rangos[c[1]] and quiere[c[2]] then
      local _, listo = lotes(c)
      table.insert(res, { id = id, c = c, prof = quiere[c[2]], listo = listo })
    end
  end
  return res
end

-- ===================== Donde caen: area de bichos de tu nivel y faccion =====================
local function enMundo(m, x, y)
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
  local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
  if not ok or not v or not v.GetXY then return nil end
  local wx, wy = v:GetXY()
  if not wx then return nil end
  return wx, wy, cont
end
local function dondeEstoy()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not m or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if not ok or not pos then return m end
  local x, y = pos.x, pos.y
  if (not x or not y) and pos.GetXY then x, y = pos:GetXY() end
  if not x or (x == 0 and y == 0) then return m end
  return m, x * 100, y * 100
end

-- Nivel de bicho desde el que caen de verdad (percentil 10 de las Apprentice en Wowhead): por debajo casi no caen
function WowF.cajasNivelMinimo()
  local d = D()
  local r = d and d.rangos and d.rangos.Apprentice
  return r and r[1] or nil
end

-- Area mas cercana y densa con bichos que sueltan cajas: tu nivel (min <= N+2, max >= N-7), atacables, tu faccion, sin ciudades
function WowF.mejorAreaCajas(opciones)
  opciones = opciones or {}
  local d, m = D(), WowFMobs
  if not d or not d.npc or not m or not m.areas then return nil, "sindatos" end
  local N = opciones.nivel or nivelPj()
  local mia = opciones.faccion or fac()
  local m0, x0, y0 = opciones.mapa, opciones.x, opciones.y
  if not m0 then m0, x0, y0 = dondeEstoy() end
  if m0 and not x0 then x0, y0 = 50, 50 end -- sin posicion (ciudad, cueva): el centro de tu mapa
  local wx0, wy0, c0
  if m0 and x0 then wx0, wy0, c0 = enMundo(m0, x0, y0) end
  local mejor, mejorPunt
  for _, a in ipairs(m.areas) do
    if zonaPermitida(a[1], mia) then
      local peso, muertes, bichos, cajas = 0, 0, {}, {}
      for _, c in ipairs(a[6] or {}) do
        local e, n = d.npc[c[1]], m.npc and m.npc[c[1]]
        if e then
          local reac = n and ((mia == 2) and n[5] or n[4]) or -1
          if e[2] <= N + 2 and e[3] >= N - 7 and (reac or -1) <= 0 then
            peso = peso + c[2] * e[1] / 100000
            muertes = muertes + c[2]
            table.insert(bichos, { id = c[1], nombre = (n and n[1]) or ("NPC " .. c[1]), min = e[2], max = e[3], veces = c[2], tasa = e[1] })
            for _, id in ipairs(e[4] or {}) do cajas[id] = true end
          end
        end
      end
      if peso > 0 then
        local dist, lejos = nil, false
        if a[1] == m0 and x0 then dist = 0 end
        local wx, wy, cc = enMundo(a[1], a[2], a[3])
        if wx and wx0 then
          if cc == c0 then dist = math.sqrt((wx - wx0) ^ 2 + (wy - wy0) ^ 2) else lejos = true end
        end
        local punt = peso / (1 + (dist or 3000) / 400)
        if lejos then punt = punt / 20 end
        if not mejorPunt or punt > mejorPunt then
          table.sort(bichos, function(p, q) return p.veces * p.tasa > q.veces * q.tasa end)
          mejor, mejorPunt = { m = a[1], x = a[2], y = a[3], radio = a[4], zona = a[5], bichos = bichos, cajas = cajas,
            cada = math.floor(muertes / peso + 0.5), dist = dist, lejos = lejos }, punt
        end
      end
    end
  end
  if not mejor then return nil, "nada" end
  return mejor
end

-- Zonas (datos de Wowhead) de tu faccion y tu nivel donde mas cajas se han visto
function WowF.zonasCajas(N, maximo)
  N = N or nivelPj()
  local d, mia, res = D(), fac(), {}
  for _, z in ipairs((d and d.zonas) or {}) do
    if zonaPermitida(z[1], mia) and z[4] <= N + 2 and z[5] >= N - 7 then table.insert(res, z) end
    if #res >= (maximo or 3) then break end
  end
  return res
end
function WowF.mazmorrasCajas(N)
  N = N or nivelPj()
  local d, res = D(), {}
  for _, z in ipairs((d and d.mazmorras) or {}) do
    if z[3] > 0 and z[3] <= N + 2 and z[4] >= N - 7 then table.insert(res, z[2]) end
  end
  return res
end

local function lineaBichos(a, max)
  local t = {}
  for i = 1, math.min(max or 4, #a.bichos) do
    local b = a.bichos[i]
    table.insert(t, b.nombre .. " (" .. L("nv ", "lvl ") .. (b.min == b.max and b.min or (b.min .. "-" .. b.max)) .. ")")
  end
  return table.concat(t, ", ")
end
local function rangosDeArea(a)
  local f, vistos, t = F(), {}, {}
  for id in pairs(a.cajas or {}) do
    local c = f and f.cajas and f.cajas[id]
    if c and not vistos[c[1]] then vistos[c[1]] = true end
  end
  for _, r in ipairs(RANGOS) do if vistos[r] then table.insert(t, r) end end
  return table.concat(t, ", ")
end

-- ----- Circulo dorado en el mapa -----
local actual, circulo
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function dibujar()
  if circulo then circulo:Hide() end
  local c = lienzo()
  if not c or not actual or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if visto ~= actual.m then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  if not circulo then
    circulo = CreateFrame("Frame", nil, c)
    circulo:SetFrameStrata("HIGH")
    pcall(function() circulo:SetFrameLevel(c:GetFrameLevel() + 5) end)
    if circulo.EnableMouse then circulo:EnableMouse(true) end
    circulo.relleno = circulo:CreateTexture(nil, "ARTWORK")
    circulo.relleno:SetAllPoints()
    circulo.relleno:SetColorTexture(1, 0.82, 0, 0.22)
    pcall(function()
      local mk = circulo:CreateMaskTexture()
      mk:SetAllPoints(circulo.relleno)
      mk:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      circulo.relleno:AddMaskTexture(mk)
    end)
    circulo.etiqueta = circulo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if WowF.estilo then WowF.estilo.letra(circulo.etiqueta, "boton", 12, "OUTLINE") end -- 11-oct (hibrido): Signika con borde sobre el mapa
    circulo.etiqueta:SetPoint("CENTER", 0, 0)
    circulo:SetScript("OnEnter", function(self)
      if not GameTooltip or not actual then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local t = ORO .. "Waylaid Crates|r\n" .. L("Mata: ", "Kill: ") .. lineaBichos(actual, 6) .. "\n"
        .. L("Aprox. 1 caja cada ", "About 1 crate per ") .. cifra(actual.cada) .. L(" muertes (", " kills (") .. rangosDeArea(actual) .. ")\n"
        .. GRIS .. L("Datos de Wowhead (WoW Forever), aproximados.", "Data from Wowhead (WoW Forever), approximate.") .. "|r"
      GameTooltip:SetText(Y(t), 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    circulo:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  local diam = ancho * actual.radio * 2 / 100
  circulo:SetSize(diam, diam)
  circulo:ClearAllPoints()
  circulo:SetPoint("CENTER", c, "TOPLEFT", ancho * actual.x / 100, -alto * actual.y / 100)
  circulo.etiqueta:SetText(((WowF.estilo and WowF.estilo.cod.oro) or ORO) .. "Waylaid Crates|r")
  circulo:Show()
end
WowF.dibujarAreaCajas = dibujar
WowF.areaCajasActual = function() return actual end
WowF.circuloAreaCajas = function() return circulo end -- pruebas
function WowF.quitarAreaCajas() actual = nil; WowFExportarDB.areaCajas = nil; if circulo then circulo:Hide() end end
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
end
local limpiarAntes = WowF.limpiarRutas
if limpiarAntes then
  WowF.limpiarRutas = function(...)
    local r = limpiarAntes(...)
    WowF.quitarAreaCajas()
    return r
  end
end

function WowF.irAreaCajas(opciones)
  local a, motivo = WowF.mejorAreaCajas(opciones)
  if not a then
    local t = motivo == "sindatos"
      and L("aún no tenemos datos de bichos de Forever para las cajas. Se actualizará en próximas actualizaciones.", "we do not have Forever mob data for crates yet. This will be updated in future updates.")
      or L("no hay un área de bichos de tu nivel y tu faccion que suelte cajas en los datos de Forever. Se actualizará en próximas actualizaciones.", "there is no mob area for your level and faction that drops crates in the Forever data. This will be updated in future updates.")
    print(AZUL .. NARANJA .. t .. "|r")
    return nil
  end
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  actual = a
  WowFExportarDB.areaCajas = true
  if WowF.marcar then pcall(WowF.marcar, { m = a.m, x = a.x, y = a.y, n = "Waylaid Crates", z = a.zona, lugar = true }) end
  print(AZUL .. Y(ORO .. "Waylaid Crates|r: " .. a.zona .. " (" .. a.x .. ", " .. a.y .. ")" .. GRIS .. L(" · circulo dorado en el mapa y alfiler en el centro", " · gold circle on the map and pin at the center") .. "|r"))
  if a.lejos then print(AZUL .. NARANJA .. L("Queda LEJOS: en tu continente aún no hay datos de tu nivel. Se actualizará en próximas actualizaciones.", "It is FAR: no data for your level on your continent yet. This will be updated in future updates.") .. "|r") end
  print(AZUL .. Y(L("mata: ", "kill: ") .. lineaBichos(a, 4)))
  print(AZUL .. Y(L("aprox. 1 caja cada ", "about 1 crate per ") .. cifra(a.cada) .. L(" muertes; aqui caen: ", " kills; here they drop: ") .. rangosDeArea(a) .. GRIS .. L(" (Wowhead, aproximado)", " (Wowhead, approximate)") .. "|r"))
  pcall(dibujar)
  if WowF.avisar then
    pcall(WowF.avisar, Y("Waylaid Crates - " .. a.zona),
      Y(L("Mata dentro del CIRCULO DORADO del mapa (M); el alfiler marca el centro.", "Kill inside the GOLD CIRCLE on the map (M); the pin marks the center.") .. "\n"
        .. VERDE .. L("Mata: ", "Kill: ") .. lineaBichos(a, 3) .. "|r\n" .. GRIS .. L("Aprox. 1 caja cada ", "About 1 crate per ") .. cifra(a.cada) .. L(" muertes.", " kills.") .. "|r"),
      nil, 9, nil, { clave = "cajas", sinChat = true })
  end
  return a
end

-- ===================== Lo que llevas en las bolsas =====================
-- { tipo = "generica"|"etiqueta"|"sellada"|"caja", id, c }
function WowF.cajasEnBolsas()
  local d, f, res = D(), F(), {}
  if not d then return res end
  if d.generica and tengo(d.generica) > 0 then table.insert(res, { tipo = "generica", id = d.generica }) end
  local l = lado()
  local et = l and d.etiquetaObj and d.etiquetaObj[l]
  if et and tengo(et) > 0 then table.insert(res, { tipo = "etiqueta", id = et }) end
  local ids = {}
  for id in pairs(d.selladas or {}) do table.insert(ids, id) end
  table.sort(ids)
  for _, id in ipairs(ids) do if tengo(id) > 0 then table.insert(res, { tipo = "sellada", id = id, c = d.selladas[id] }) end end
  local ids2 = {}
  for id in pairs((f and f.cajas) or {}) do table.insert(ids2, id) end
  table.sort(ids2)
  for _, id in ipairs(ids2) do if tengo(id) > 0 then table.insert(res, { tipo = "caja", id = id, c = f.cajas[id] }) end end
  return res
end
local CALIDAD = { [1] = { "blanca", "white" }, [2] = { "verde", "green" }, [3] = { "azul", "blue" } }
local function favorSellada(s)
  if s[4] then return ORO .. s[4] .. " Merchant's Favor|r" end
  return NARANJA .. "Favor: " .. sinConfirmar() .. "|r"
end

-- ===================== Seccion del Libro: version por tarjetas (11-oct) =====================
-- La usa la vista de Profesiones (wowF_VistaProfesiones.lua) cuando su "h" trae h.tarjetas(fn): fn(k, x, y, w) dibuja con el
-- kit (WowF.vistaKit) y devuelve la y final. Mismos datos, textos, clics y tooltips que la version de texto de abajo.
local function lotesFilas(c)
  local res = {}
  for _, lote in ipairs(c[5] or {}) do
    local n = tengo(lote[1])
    local falta = lote[2] - n
    table.insert(res, { listo = falta <= 0, n = n, total = lote[2],
      texto = lote[2] .. " x " .. lote[3] .. "  (" .. L("tienes ", "you have ") .. n
        .. (falta > 0 and (L(", te faltan ", ", you need ") .. falta .. L("", " more")) or L(": LISTO", ": READY")) .. ")" })
  end
  return res
end

local function tarjetasCajas(k, x, y, w, h)
  local K = WowF.vistaKit or {}
  local C = (WowF.estilo and WowF.estilo.color) or {}
  local cod = (WowF.estilo and WowF.estilo.cod) or {}
  local cOro, cBrasa, cTenue, cTexto, cVerde = cod.oro or ORO, cod.brasa or NARANJA, cod.tenue or GRIS, cod.texto or BLANCO, cod.verde or VERDE
  local CRATE = "Interface\\Icons\\INV_Crate_04"
  local IX = 16
  local d, f = D(), F()
  local t, ty, cy
  local function abrir(rotulo, titulo, variante)
    ty = y
    t = k:tarjeta(x, ty, w, 40, variante)
    cy = ty + 14
    if rotulo then k:rotulo(x + IX, cy, rotulo, C.oro); cy = cy + 20 end
    if titulo then
      local _, hh = k:texto(x + IX, cy, titulo, { tam = 18, letra = "marca", color = C.texto, ancho = w - 2 * IX })
      cy = cy + hh + 8
    end
  end
  local function cerrar()
    local fin = cy + 6
    t:SetHeight(fin - ty)
    k:hasta(fin)
    y = fin + 12
  end
  local function parrafo(txt, color, tam, sangria)
    local sx = x + IX + (sangria or 0)
    local _, hh = k:texto(sx, cy, txt, { tam = tam or 13, color = color or C.tenue, ancho = x + w - IX - sx })
    cy = cy + hh + 8
  end
  -- Fila en casilla: icono, titulo, texto y boton opcional. o = { icono, borde, titulo, colorTitulo, sub, boton, fn, ayudaBoton, objeto, chip, colorChip }
  local function fila(o)
    local bx, by, bw = x + IX, cy, w - 2 * IX
    local cas = k:tarjeta(bx, by, bw, 60, nil, K.CASILLA, o.borde or K.CASILLA_BORDE, true)
    k:icono(bx + 12, by + 12, 36, o.icono or CRATE, o.colorIcono)
    local tx, der = bx + 12 + 36 + 12, bx + bw - 12
    local cw = 0
    if o.chip then local _, w1 = k:chip(der, by + 10, o.chip, o.colorChip or "neutro", true); cw = (w1 or 60) + 8 end
    local _, h1 = k:texto(tx, by + 12, o.titulo, { tam = 15, letra = "marca", color = o.colorTitulo or C.texto, ancho = der - cw - tx })
    local yy = by + 12 + h1 + 4
    if o.sub and o.sub ~= "" then
      local _, h2 = k:texto(tx, yy, o.sub, { tam = 12, color = C.tenue, ancho = der - tx })
      yy = yy + h2 + 6
    end
    if o.boton then
      k:boton(tx, yy, o.boton, o.estandarte and "estandarte" or "secundario", true, o.fn, { ayuda = o.ayudaBoton })
      yy = yy + 28 + 4
    end
    local fin = math.max(yy + 6, by + 12 + 36 + 12)
    cas:SetHeight(fin - by)
    if o.objeto then
      local id, nom = o.objeto, o.titulo
      -- la zona va solo sobre icono y titulo para no tapar el boton
      k:zona(bx, by, bw, 12 + h1 + 4, nil, function(tt)
        local ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, id)
        if not ok then tt:SetText((tostring(nom or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), 1, 1, 1) end
      end)
    end
    cy = fin + 8
  end

  -- Cabecera de la guia
  abrir(L("Cajas del mundo", "World crates"), ORO .. L("Guia de Waylaid Crates", "Waylaid Crates guide") .. "|r", "principal")
  if not d or not f then
    parrafo(L("Faltan los datos de las cajas: reinstala el addon.", "Crate data is missing: reinstall the addon."))
    cerrar(); return y
  end
  local l = lado()
  if not l then
    parrafo(L("Elige faccion primero: la entrega y las zonas dependen de ella.", "Choose a faction first: the turn-in and the zones depend on it."))
    cerrar(); return y
  end
  local N = nivelPj()
  local nv = (WowF.favorNivel and WowF.favorNivel()) or 10
  parrafo(L("Caen de bichos del mundo, las llenas con lo que sacan tus profesiones y las entregas a cambio de Merchant's Favor.",
    "They drop from world mobs, you fill them with what your professions gather and turn them in for Merchant's Favor."), C.texto)
  if N < nv then
    k:chip(x + IX, cy, L("Nivel ", "Level ") .. nv .. L(" para usarlas", " to use them"), "brasa")
    cy = cy + 26
    parrafo(Y(cBrasa .. L("Las cajas piden nivel ", "Crates require level ") .. nv .. L(" para usarlas: puedes guardarlas desde ya.", " to use them: you can keep them from now on.") .. "|r"), C.brasa)
  else
    k:chip(x + IX, cy, L("Ya puedes usarlas", "You can use them now"), "verde")
    cy = cy + 28
  end
  cerrar()

  -- 1. Donde caen
  abrir(L("Paso 1", "Step 1"), L("1. Donde caen", "1. Where they drop"))
  parrafo(L("De cualquier bicho del mundo de su nivel (no hay que buscar uno concreto).", "From any world mob of their level (no specific mob needed)."), C.texto)
  local ahora, proximo = WowF.cajasRangos(N)
  if #ahora > 0 then
    k:rotulo(x + IX, cy, L("A tu nivel", "At your level"), C.verde)
    cy = cy + 20
    for _, r in ipairs(ahora) do
      k:icono(x + IX, cy, 20, CRATE, "oro")
      local _, hh = k:texto(x + IX + 28, cy + 3, Y(cTexto .. r.rango .. "|r" .. cTenue .. L(" (bichos nv ", " (mobs lvl ") .. r.min .. "-" .. r.max .. L(", aprox. 1 de cada ", ", about 1 per ") .. cifra(r.cada) .. ")|r"),
        { tam = 13, color = C.texto, ancho = w - 2 * IX - 28 })
      cy = cy + math.max(20, hh + 3) + 6
    end
  end
  if proximo then
    parrafo(Y(cTenue .. L("Despues: ", "Later: ") .. proximo.rango .. L(" (bichos nv ", " (mobs lvl ") .. proximo.min .. "-" .. proximo.max .. ")"
      .. (proximo.vistas < 50 and (". " .. cBrasa .. L("Pocos datos todavia: ", "Very little data yet: ") .. sinConfirmar()) or "") .. "|r"))
  end
  local minimo = WowF.cajasNivelMinimo()
  local a = WowF.mejorAreaCajas()
  if not a and minimo and N + 2 < minimo then
    parrafo(L("Aun no: las cajas caen sobre todo de bichos de nivel ", "Not yet: crates mostly drop from mobs of level ") .. minimo .. L(" en adelante. Vuelve aqui al nivel ", " and up. Come back at level ") .. (minimo - 2) .. ".", C.brasa)
  elseif a then
    fila({ icono = CRATE, colorIcono = "verde", borde = C.verdeBorde,
      titulo = Y(cVerde .. L("Mejor sitio para ti: ", "Best spot for you: ") .. "|r" .. cTexto .. a.zona .. " " .. a.x .. ", " .. a.y .. "|r"),
      chip = a.lejos and L("LEJOS", "FAR") or nil, colorChip = "brasa",
      sub = Y(L("Mata: ", "Kill: ") .. lineaBichos(a, 3) .. "\n" .. L("Aprox. 1 caja cada ", "About 1 crate per ") .. cifra(a.cada) .. L(" muertes", " kills")),
      boton = L("Círculo dorado en el mapa", "Gold circle on the map"), estandarte = true, fn = function() WowF.irAreaCajas() end,
      ayudaBoton = L("Marca en el mapa el área donde más caen a tu nivel, con un alfiler en el centro.", "Marks on the map the area where most drop at your level, with a pin at the center.") })
  else
    parrafo(L("Aun no hay un área de bichos de tu nivel y faccion con cajas en los datos de Forever; se actualizará en próximas actualizaciones.", "There is no mob area for your level and faction with crates in the Forever data yet; it will be updated in future updates."), C.brasa)
  end
  local zs = WowF.zonasCajas(N, 3)
  if #zs > 0 then
    local tz = {}
    for _, z in ipairs(zs) do table.insert(tz, z[3] .. " (" .. z[4] .. "-" .. z[5] .. ")") end
    local mz = WowF.mazmorrasCajas(N)
    parrafo(Y(L("Donde mas se han visto: ", "Where most were seen: ") .. table.concat(tz, ", ")
      .. (#mz > 0 and (L(". Tambien en mazmorras: ", ". Also in dungeons: ") .. table.concat(mz, ", ")) or "") .. "."), C.tenue, 12)
  end
  cerrar()

  -- 2. Que caja te conviene
  abrir(L("Paso 2", "Step 2"), L("2. Que caja te conviene", "2. Which crate suits you"))
  local profs = profesionesCaja()
  local nombres = {}
  for _, pr in ipairs(profs) do table.insert(nombres, (NOMBRE_PROF[pr.id] or "?") .. (pr.delPlan and L(" (del plan)", " (from your plan)") or "")) end
  parrafo(Y(#nombres > 0 and (L("Con ", "With ") .. table.concat(nombres, ", ") .. L(": las que llenas tu mismo.", ": the ones you fill yourself."))
    or L("Sin profesiones de cajas: Textiles se llena con tela de humanoides.", "No crate professions: Textiles is filled with cloth from humanoids.")))
  local recs = WowF.cajasRecomendadas(N)
  local BW = 110
  for i = 1, math.min(6, #recs) do
    local r = recs[i]
    local filas = lotesFilas(r.c)
    local listo = false
    for _, lf in ipairs(filas) do if lf.listo then listo = true end end
    local niv = r.c[4] or 10
    local bx, by, bw = x + IX, cy, w - 2 * IX
    local cas = k:tarjeta(bx, by, bw, 60, nil, K.CASILLA, listo and C.verdeBorde or K.CASILLA_BORDE, true)
    k:icono(bx + 12, by + 12, 36, (h.icono and h.icono(nil, r.id)) or CRATE, listo and "verde" or nil)
    local tx, der = bx + 12 + 36 + 12, bx + bw - 12
    local _, cw = k:chip(der, by + 10, L("Nivel ", "Level ") .. niv, N < niv and "brasa" or "neutro", true)
    local ocupado = (cw or 60) + 8
    if listo then
      local _, cw2 = k:chip(der - ocupado, by + 10, L("LOTE COMPLETO", "BUNDLE READY"), "verde", true)
      ocupado = ocupado + (cw2 or 100) + 8
    end
    local nombre = "Waylaid Crate: " .. nombreCaja(r.c)
    local _, h1 = k:texto(tx, by + 12, Y(nombre), { tam = 15, letra = "marca", color = listo and C.verde or C.texto, ancho = der - ocupado - tx })
    local yy = by + 12 + h1 + 4
    local _, h2 = k:texto(tx, yy, L("Pide UNO de estos lotes:", "Asks for ONE of these bundles:"), { tam = 12, color = C.tenue, ancho = der - tx })
    yy = yy + h2 + 6
    for _, lf in ipairs(filas) do
      local _, h3 = k:texto(tx, yy, Y(lf.texto), { tam = 13, color = lf.listo and C.verde or C.texto, ancho = der - BW - 12 - tx })
      k:barra(der - BW, yy + math.max(0, math.floor(((h3 or 14) - 8) / 2)), BW, math.min(lf.n, lf.total), lf.total, lf.listo and "verde" or nil)
      yy = yy + math.max(h3 or 14, 12) + 6
    end
    local fin = math.max(yy + 4, by + 12 + 36 + 12)
    cas:SetHeight(fin - by)
    local id = r.id
    k:zona(bx, by, bw, fin - by, nil, function(tt)
      local ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, id)
      if not ok then tt:SetText(nombre, 1, 1, 1) end
    end)
    cy = fin + 8
  end
  parrafo(L("No eliges que caja te cae: si sale una de otro tipo, el lote tambien se compra en la casa de subastas.", "You do not choose which crate drops: if you get another type, the bundle can also be bought at the auction house."), C.tenue, 12)
  cerrar()

  -- Lo que llevas en las bolsas
  local mias = WowF.cajasEnBolsas()
  local e = WowF.entregaFavor and WowF.entregaFavor()
  local quien = e and e.n or "?"
  if #mias > 0 then
    abrir(L("Lo que llevas", "What you carry"), nil)
    for _, m in ipairs(mias) do
      local ico = h.icono and h.icono(nil, m.id)
      if m.tipo == "generica" then
        fila({ icono = ico, objeto = m.id, titulo = Y(L("En tus bolsas: ", "In your bags: ") .. "Waylaid Crate"),
          sub = Y(L("Usala: lees la etiqueta y te dice que envio es (Wowhead: \"Read the label to identify the shipment\"). En que caja se convierte: ", "Use it: you read the label and it tells you which shipment it is (Wowhead: \"Read the label to identify the shipment\"). Which crate it becomes: ") .. cBrasa .. sinConfirmar() .. "|r") })
      elseif m.tipo == "etiqueta" then
        fila({ icono = ico, objeto = m.id, titulo = Y(L("En tus bolsas: ", "In your bags: ") .. "Shipping Label"),
          sub = Y(L("Empieza una mision: entregala a ", "Starts a quest: turn it in to ") .. quien .. L(" (50 Merchant's Favor la primera vez).", " (50 Merchant's Favor the first time).")),
          boton = L("Ruta a la entrega", "Route to the turn-in"), fn = function() WowF.irEntregaFavor() end })
      elseif m.tipo == "sellada" then
        local cal = CALIDAD[m.c[2]] or { "?", "?" }
        fila({ icono = ico, objeto = m.id, titulo = Y(L("En tus bolsas: ", "In your bags: ") .. "Sealed " .. m.c[1] .. " Crate" .. cTenue .. " (" .. L(cal[1], cal[2]) .. ")|r"),
          chip = m.c[4] and (m.c[4] .. " Favor") or nil, colorChip = "oro",
          sub = Y(L("Entrégala a ", "Turn it in to ") .. quien .. ": " .. favorSellada(m.c)),
          boton = L("Ruta a la entrega", "Route to the turn-in"), fn = function() WowF.irEntregaFavor() end })
      end
    end
    cerrar()
  end

  -- 3. Donde se entregan
  if e then
    abrir(L("Paso 3", "Step 3"), L("3. Donde se entregan", "3. Where to turn them in"))
    fila({ icono = CRATE, colorIcono = "oro", titulo = Y(e.n .. cTenue .. " · " .. (e.zona or "") .. " " .. e.x .. ", " .. e.y .. "|r"),
      sub = L("Al llenarla queda sellada (Sealed Crate): entregala aqui.", "Once filled it becomes sealed (Sealed Crate): turn it in here."),
      boton = L("Ruta y alfiler", "Route and pin"), estandarte = true, fn = function() WowF.irEntregaFavor() end,
      ayudaBoton = L("Ruta paso a paso hasta el NPC y alfiler en el mapa.", "Step-by-step route to the NPC and a pin on the map.") })
    cerrar()
  end

  -- Favor por caja y lo que aun no se sabe (siempre al final)
  abrir(L("Favor por caja", "Favor per crate"), nil, "hundida")
  local fav = {}
  for _, r in ipairs({ "Apprentice", "Journeyman" }) do
    local b, v
    for _, s in pairs(d.selladas or {}) do if s[1] == r and s[2] == 1 then b = s[4] elseif s[1] == r and s[2] == 2 then v = s[4] end end
    if b and v then table.insert(fav, r .. " " .. b .. L(" (blanca) / ", " (white) / ") .. v .. L(" (verde)", " (green)")) end
  end
  local et = f.etiqueta and f.etiqueta[l]
  local etHecha = et and hecha(et.q)
  parrafo(Y(L("Favor: ", "Favor: ") .. (et and ((etHecha and L("Shipping Label ya entregada; ", "Shipping Label already turned in; ") or L("la primera vez, 50 por la Shipping Label (una sola vez); luego, ", "the first time, 50 for the Shipping Label (once only); then, "))) or "")
    .. L("por caja: ", "per crate: ") .. table.concat(fav, "; ") .. ". Expert / Artisan / Elite " .. L("y las azules: ", "and blue ones: ") .. sinConfirmar() .. "."), C.texto)
  if WowF.notaLegacyFavor and WowF.notaLegacyFavor() then parrafo(WowF.notaLegacyFavor(), C.texto) end
  parrafo(L("Sin confirmar (se actualizará en próximas actualizaciones): de dónde sale la Shipping Label, en qué caja se convierte la Waylaid Crate al leer la etiqueta y qué decide si la sellada sale blanca, verde o azul. Las tasas son aproximadas (muertes vistas por Wowhead).",
    "Unconfirmed (it will be updated in future updates): where the Shipping Label comes from, which crate the Waylaid Crate becomes when you read the label, and what makes the sealed crate white, green or blue. Rates are approximate (kills seen by Wowhead)."), C.brasa, 12)
  cerrar()
  return y
end

-- ===================== Seccion del Libro =====================
function WowF.seccionCajas(p, h)
  if h and h.tarjetas then
    return h.tarjetas(function(k, x, y, w) return tarjetasCajas(k, x, y, w, h) end)
  end
  local d, f = D(), F()
  h.cab(ORO .. L("Guia de Waylaid Crates", "Waylaid Crates guide") .. "|r")
  if not d or not f then
    h.nota(GRIS .. L("Faltan los datos de las cajas: reinstala el addon.", "Crate data is missing: reinstall the addon.") .. "|r")
    return
  end
  local l = lado()
  if not l then
    h.nota(GRIS .. L("Elige faccion primero: la entrega y las zonas dependen de ella.", "Choose a faction first: the turn-in and the zones depend on it.") .. "|r")
    return
  end
  local N = nivelPj()
  local nv = (WowF.favorNivel and WowF.favorNivel()) or 10
  if N < nv then
    h.nota(Y(NARANJA .. L("Las cajas piden nivel ", "Crates require level ") .. nv .. L(" para usarlas: puedes guardarlas desde ya.", " to use them: you can keep them from now on.") .. "|r"))
  end
  -- 1. Donde caen
  local ahora, proximo = WowF.cajasRangos(N)
  local partes = {}
  for _, x in ipairs(ahora) do
    table.insert(partes, x.rango .. L(" (bichos nv ", " (mobs lvl ") .. x.min .. "-" .. x.max .. L(", aprox. 1 de cada ", ", about 1 per ") .. cifra(x.cada) .. ")")
  end
  h.nota(Y(ORO .. L("1. Donde caen", "1. Where they drop") .. "|r  " .. BLANCO .. L("De cualquier bicho del mundo de su nivel (no hay que buscar uno concreto). ", "From any world mob of their level (no specific mob needed). ")
    .. (#partes > 0 and (L("A tu nivel: ", "At your level: ") .. table.concat(partes, "; ") .. ".") or "") .. "|r"))
  if proximo then
    h.nota(Y(GRIS .. L("Despues: ", "Later: ") .. proximo.rango .. L(" (bichos nv ", " (mobs lvl ") .. proximo.min .. "-" .. proximo.max .. ")"
      .. (proximo.vistas < 50 and (". " .. NARANJA .. L("Pocos datos todavia: ", "Very little data yet: ") .. sinConfirmar()) or "") .. "|r"))
  end
  local minimo = WowF.cajasNivelMinimo()
  local a = WowF.mejorAreaCajas()
  if not a and minimo and N + 2 < minimo then
    h.nota(Y(GRIS .. L("Aun no: las cajas caen sobre todo de bichos de nivel ", "Not yet: crates mostly drop from mobs of level ") .. minimo .. L(" en adelante. Vuelve aqui al nivel ", " and up. Come back at level ") .. (minimo - 2) .. ".|r"))
  elseif a then
    h.item({ texto = Y(VERDE .. L("Mejor sitio para ti: ", "Best spot for you: ") .. "|r" .. BLANCO .. a.zona .. " " .. a.x .. ", " .. a.y .. "|r"
      .. (a.lejos and (NARANJA .. L("  (LEJOS)", "  (FAR)") .. "|r") or "")),
      sub = Y(GRIS .. L("Mata: ", "Kill: ") .. lineaBichos(a, 3) .. "\n" .. L("Aprox. 1 caja cada ", "About 1 crate per ") .. cifra(a.cada) .. L(" muertes", " kills")
        .. "  ·  " .. VERDE .. L("clic: circulo dorado en el mapa", "click: gold circle on the map") .. "|r"),
      icono = "Interface\\Icons\\INV_Crate_04", chico = true, accion = function() WowF.irAreaCajas() end })
  else
    h.nota(GRIS .. L("Aun no hay un área de bichos de tu nivel y faccion con cajas en los datos de Forever; se actualizará en próximas actualizaciones.", "There is no mob area for your level and faction with crates in the Forever data yet; it will be updated in future updates.") .. "|r")
  end
  local zs = WowF.zonasCajas(N, 3)
  if #zs > 0 then
    local t = {}
    for _, z in ipairs(zs) do table.insert(t, z[3] .. " (" .. z[4] .. "-" .. z[5] .. ")") end
    local mz = WowF.mazmorrasCajas(N)
    h.nota(Y(GRIS .. L("Donde mas se han visto: ", "Where most were seen: ") .. table.concat(t, ", ")
      .. (#mz > 0 and (L(". Tambien en mazmorras: ", ". Also in dungeons: ") .. table.concat(mz, ", ")) or "") .. ".|r"))
  end
  -- 2. Que caja te conviene
  local profs = profesionesCaja()
  local nombres = {}
  for _, pr in ipairs(profs) do table.insert(nombres, (NOMBRE_PROF[pr.id] or "?") .. (pr.delPlan and L(" (del plan)", " (from your plan)") or "")) end
  h.nota(Y(ORO .. L("2. Que caja te conviene", "2. Which crate suits you") .. "|r  " .. GRIS
    .. (#nombres > 0 and (L("con ", "with ") .. table.concat(nombres, ", ") .. L(": las que llenas tu mismo.", ": the ones you fill yourself."))
      or L("sin profesiones de cajas: Textiles se llena con tela de humanoides.", "no crate professions: Textiles is filled with cloth from humanoids.")) .. "|r"))
  local recs = WowF.cajasRecomendadas(N)
  for i = 1, math.min(6, #recs) do
    local r = recs[i]
    local texto, listo = lotes(r.c)
    local niv = r.c[4] or 10
    h.item({ texto = Y((listo and VERDE or CELESTE) .. "Waylaid Crate: " .. nombreCaja(r.c) .. "|r" .. (listo and (VERDE .. L("  LOTE COMPLETO", "  BUNDLE READY") .. "|r") or "")
      .. (N < niv and (NARANJA .. L("  (nivel ", "  (level ") .. niv .. ")|r") or "")),
      sub = Y(GRIS .. L("Pide UNO de estos lotes:", "Asks for ONE of these bundles:") .. "|r\n" .. texto), icono = h.icono and h.icono(nil, r.id), objeto = r.id, sangria = 12, chico = true })
  end
  h.nota(GRIS .. L("No eliges que caja te cae: si sale una de otro tipo, el lote tambien se compra en la casa de subastas.", "You do not choose which crate drops: if you get another type, the bundle can also be bought at the auction house.") .. "|r")
  -- 3. Lo que llevas
  local mias = WowF.cajasEnBolsas()
  local e = WowF.entregaFavor and WowF.entregaFavor()
  local quien = e and e.n or "?"
  for _, x in ipairs(mias) do
    if x.tipo == "generica" then
      h.item({ texto = Y(VERDE .. L("En tus bolsas: ", "In your bags: ") .. "|r" .. BLANCO .. "Waylaid Crate|r"),
        sub = Y(GRIS .. L("Usala: lees la etiqueta y te dice que envio es (Wowhead: \"Read the label to identify the shipment\"). En que caja se convierte: ", "Use it: you read the label and it tells you which shipment it is (Wowhead: \"Read the label to identify the shipment\"). Which crate it becomes: ") .. NARANJA .. sinConfirmar() .. "|r"),
        icono = h.icono and h.icono(nil, x.id), objeto = x.id, sangria = 12, chico = true })
    elseif x.tipo == "etiqueta" then
      h.item({ texto = Y(VERDE .. L("En tus bolsas: ", "In your bags: ") .. "|r" .. BLANCO .. "Shipping Label|r"),
        sub = Y(GRIS .. L("Empieza una mision: entregala a ", "Starts a quest: turn it in to ") .. quien .. L(" (50 Merchant's Favor la primera vez).", " (50 Merchant's Favor the first time).") .. "  " .. VERDE .. L("clic: ruta", "click: route") .. "|r"),
        icono = h.icono and h.icono(nil, x.id), objeto = x.id, sangria = 12, chico = true, accion = function() WowF.irEntregaFavor() end })
    elseif x.tipo == "sellada" then
      local cal = CALIDAD[x.c[2]] or { "?", "?" }
      h.item({ texto = Y(VERDE .. L("En tus bolsas: ", "In your bags: ") .. "|r" .. BLANCO .. "Sealed " .. x.c[1] .. " Crate|r" .. GRIS .. " (" .. L(cal[1], cal[2]) .. ")|r"),
        sub = Y(L("Entrégala a ", "Turn it in to ") .. quien .. ": " .. favorSellada(x.c) .. "  " .. VERDE .. L("clic: ruta a la entrega", "click: route to the turn-in") .. "|r"),
        icono = h.icono and h.icono(nil, x.id), objeto = x.id, sangria = 12, chico = true, accion = function() WowF.irEntregaFavor() end })
    end
  end
  -- 4. Entrega y Favor
  if e then
    h.item({ texto = Y(ORO .. L("3. Donde se entregan: ", "3. Where to turn them in: ") .. "|r" .. BLANCO .. e.n .. ", " .. (e.zona or "") .. " " .. e.x .. ", " .. e.y .. "|r"),
      sub = Y(GRIS .. L("Al llenarla queda sellada (Sealed Crate): entregala aqui.", "Once filled it becomes sealed (Sealed Crate): turn it in here.") .. "  " .. VERDE .. L("clic: ruta y alfiler", "click: route and pin") .. "|r"),
      icono = "Interface\\Icons\\INV_Crate_04", chico = true, accion = function() WowF.irEntregaFavor() end })
  end
  local fav = {}
  for _, r in ipairs({ "Apprentice", "Journeyman" }) do
    local b, v
    for _, s in pairs(d.selladas or {}) do if s[1] == r and s[2] == 1 then b = s[4] elseif s[1] == r and s[2] == 2 then v = s[4] end end
    if b and v then table.insert(fav, r .. " " .. b .. L(" (blanca) / ", " (white) / ") .. v .. L(" (verde)", " (green)")) end
  end
  local et = f.etiqueta and f.etiqueta[l]
  local etHecha = et and hecha(et.q)
  h.nota(Y(GRIS .. L("Favor: ", "Favor: ") .. (et and ((etHecha and L("Shipping Label ya entregada; ", "Shipping Label already turned in; ") or L("la primera vez, 50 por la Shipping Label (una sola vez); luego, ", "the first time, 50 for the Shipping Label (once only); then, ")))  or "")
    .. L("por caja: ", "per crate: ") .. table.concat(fav, "; ") .. ". Expert / Artisan / Elite " .. L("y las azules: ", "and blue ones: ") .. sinConfirmar() .. ".|r"))
  if WowF.notaLegacyFavor and WowF.notaLegacyFavor() then h.nota(WowF.notaLegacyFavor()) end
  -- Sin confirmar
  h.nota(Y(NARANJA .. L("Sin confirmar (se actualizará en próximas actualizaciones): de dónde sale la Shipping Label, en qué caja se convierte la Waylaid Crate al leer la etiqueta y qué decide si la sellada sale blanca, verde o azul. Las tasas son aproximadas (muertes vistas por Wowhead).",
    "Unconfirmed (it will be updated in future updates): where the Shipping Label comes from, which crate the Waylaid Crate becomes when you read the label, and what makes the sealed crate white, green or blue. Rates are approximate (kills seen by Wowhead).") .. "|r"))
end

-- En el Libro va justo debajo de Merchant's Favor (sin tocar wowF_Favor.lua: se envuelve su seccion)
local seccionFavorAntes = WowF.seccionFavor
if seccionFavorAntes then
  WowF.seccionFavor = function(p, h)
    seccionFavorAntes(p, h)
    if h.separador then h.separador() end
    local ok, err = pcall(WowF.seccionCajas, p, h)
    if not ok and h.nota then h.nota(GRIS .. "Waylaid Crates: " .. tostring(err) .. "|r") end
  end
end

-- ===================== Chat: /wowf cajas =====================
function WowF.cajasResumen()
  local d, f = D(), F()
  if not d or not f or not lado() then
    print(AZUL .. NARANJA .. L("faltan los datos de las cajas o tu faccion.", "crate data or your faction is missing.") .. "|r")
    return
  end
  local N = nivelPj()
  local ahora = WowF.cajasRangos(N)
  local t = {}
  for _, x in ipairs(ahora) do table.insert(t, x.rango .. " (" .. L("1 de cada ", "1 per ") .. cifra(x.cada) .. ")") end
  print(AZUL .. Y(ORO .. "Waylaid Crates|r: " .. L("caen de bichos del mundo de su nivel. ", "they drop from world mobs of their level. ")
    .. (#t > 0 and (L("A tu nivel: ", "At your level: ") .. table.concat(t, ", ") .. ".") or "")))
  local a = WowF.mejorAreaCajas()
  if a then print(AZUL .. Y(L("mejor sitio: ", "best spot: ") .. a.zona .. " " .. a.x .. ", " .. a.y .. GRIS .. " (" .. lineaBichos(a, 2) .. L("). /wowf cajas mapa = circulo en el mapa.", "). /wowf crates map = circle on the map.") .. "|r")) end
  for _, r in ipairs(WowF.cajasRecomendadas(N)) do
    local _, listo = lotes(r.c)
    print(AZUL .. Y((listo and VERDE or CELESTE) .. nombreCaja(r.c) .. "|r" .. (listo and (VERDE .. L(": tienes un lote completo", ": you have a full bundle") .. "|r") or (GRIS .. L(": aun te faltan materiales", ": you still need materials") .. "|r"))))
  end
  local e = WowF.entregaFavor and WowF.entregaFavor()
  if e then print(AZUL .. Y(L("entrega: ", "turn-in: ") .. e.n .. ", " .. (e.zona or "") .. " " .. e.x .. ", " .. e.y .. GRIS .. L(" (/wowf cajas entrega = ruta). Detalle en el Libro, pestana Profesiones.", " (/wowf crates turnin = route). Details in the Book, Professions tab.") .. "|r")) end
end

local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "cajas" or orden == "crates" or orden == "caja" or orden == "crate" then
    if resto == "mapa" or resto == "map" or resto == "farmear" or resto == "farm" then
      WowF.irAreaCajas()
    elseif resto == "entrega" or resto == "turnin" or resto == "ruta" or resto == "route" then
      if WowF.irEntregaFavor then WowF.irEntregaFavor() end
    elseif resto == "quitar" or resto == "off" or resto == "clear" then
      WowF.quitarAreaCajas()
      print(AZUL .. L("circulo de cajas quitado del mapa.", "crate circle removed from the map."))
    else
      WowF.cajasResumen()
      if WowF.abrirLibro then pcall(WowF.abrirLibro, "Profesiones") end
    end
    return
  end
  if anterior then anterior(mensaje) end
end

-- Tras /reload: vuelve a dibujar el circulo si lo tenias
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if WowFExportarDB.areaCajas and not actual then
    local ok, a = pcall(WowF.mejorAreaCajas)
    if ok and a then actual = a; pcall(dibujar) end
  end
end)
