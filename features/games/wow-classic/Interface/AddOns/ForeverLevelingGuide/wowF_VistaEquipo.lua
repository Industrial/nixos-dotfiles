-- Forever Leveling Guide: pestana Equipo por tarjetas (11-oct, maqueta equipo.html aprobada por Andy).
-- WowF.vistaEquipo (contrato en CONTRATO.md). Izquierda: "Lo que llevas" (casillas alrededor de la figura, armas abajo).
-- Derecha: filtro de mejoras, la siguiente mejora del hueco elegido, la BiS 30 de ese hueco y la mejor mazmorra para tu equipo.
-- Datos: WowF.equipoGuia (misiones y mazmorras verificadas de WoW Forever), p.eventos (fabricadas de tu plan),
-- WowF.equipoBiS (lista BiS de foreverchanges.pro), WowF.puntuacionEquipo / WowF.rangoHueco. Usa el kit de wowF_VistaCombate.lua.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local unpack = unpack or table.unpack

local function E() return WowF.estilo end
local function C() return (WowF.estilo and WowF.estilo.color) or {} end
local function SIN_DATOS() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end

-- Colores de la maqueta (equipo.html)
local MUNECO = { 0.102, 0.086, 0.075 }     -- #1a1613
local FIGURA = { 0.082, 0.071, 0.059 }     -- #15120f
local FIGURA_BORDE = { 0.184, 0.165, 0.145 } -- #2f2a25
local SILUETA = { 0.141, 0.125, 0.11 }     -- #24201c
local VACIA = { 0.078, 0.071, 0.063 }      -- #141210
local BORDE_OK = { 0.353, 0.318, 0.282 }   -- #5a5148
local MZE = { 0.169, 0.141, 0.129 }        -- #2b2421
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- Huecos de la figura: izquierda, derecha y armas (como la hoja de personaje)
local IZQ = { 1, 2, 3, 15, 5, 9, 10 }
local DER = { 6, 7, 8, 11, 12, 13, 14 }
local ARMAS = { 16, 17, 18 }
local NOMBRE = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
  [6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
  [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged" }
local RELIQUIA = { PALADIN = true, SHAMAN = true, DRUID = true }
-- Tipo de objeto (inv) de una fabricada -> hueco de la figura (igual que SLOT de wowF_Libro.lua)
local SLOT = { [1] = 1, [2] = 2, [3] = 3, [16] = 15, [5] = 5, [20] = 5, [9] = 9, [10] = 10, [6] = 6, [7] = 7, [8] = 8, [11] = 11, [12] = 13,
  [13] = 16, [17] = 16, [21] = 16, [14] = 17, [22] = 17, [23] = 17, [15] = 18, [25] = 18, [26] = 18, [28] = 18 }

-- Medidas (px, como la maqueta)
local MUNECO_W, GAP = 400, 12
local CAS_W, ICO, CAS_H, CAS_GAP = 62, 44, 58, 8
local COL_W = 96
local ALTO_BASE = 584

local function llamar(f, ...)
  if WowF.llamar then return WowF.llamar(f, ...) end
  if type(f) ~= "function" then return nil end
  local ok, a = pcall(f, ...)
  if ok then return a end
  return nil
end
local function nivelPj() return tonumber(llamar(UnitLevel, "player") or "") or 1 end
local function obj(id)
  local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  if o then return o[1], o[2], o[3] end
  return tostring(id or "?"), 1, ""
end
local function iconoObj(ic, id) -- 12-oct: cliente primero, ic = respaldo del mismo objeto
  return WowF.iconoObjeto and WowF.iconoObjeto(id, ic) or nil
end
local function trozos(t)
  local res = {}
  for x in (tostring(t or "") .. " · "):gmatch("(.-) · ") do if x ~= "" then table.insert(res, x) end end
  return res
end
local function nombreHueco(s)
  if s == 18 then
    local clase
    if type(UnitClass) == "function" then
      local ok, _, c = pcall(UnitClass, "player")
      if ok and type(c) == "string" then clase = c end
    end
    if RELIQUIA[clase or ""] then return "Relic" end
  end
  return NOMBRE[s] or "?"
end
local function puesto(s)
  local link = llamar(GetInventoryItemLink, "player", s)
  if type(link) ~= "string" or link == "" or (issecretvalue and issecretvalue(link)) then return nil end
  local tex = llamar(GetInventoryItemTexture, "player", s)
  return { link = link, nombre = link:match("%[(.-)%]") or "?", tex = tex }
end

-- 13-oct (Andy: "la puntuacion confunde; quiero simular si me pongo esta pieza"): ayudas de la puntuacion y del bloque
-- "Si te la pones:" (WowF.simularPieza / WowF.puntuacionExplicacion de wowF_EquipoGuia.lua; si aun no existen, no sale nada).
-- Todo en una tabla: tope de locales.
local PUN = { MAX_STATS = 6 }
function PUN.hex(c)
  if type(c) ~= "table" then return "|cffffffff" end
  local function b(v) v = tonumber(v) or 1; return math.max(0, math.min(255, math.floor(v * 255 + 0.5))) end
  return string.format("|cff%02x%02x%02x", b(c[1] or c.r), b(c[2] or c.g), b(c[3] or c.b))
end
-- Rojo < 40, amarillo < 75, verde >= 75 (igual que la barra)
function PUN.colorValor(v)
  v = tonumber(v) or 0
  if v < 40 then return "|cffc7402f", 0.78, 0.25, 0.2 elseif v < 75 then return "|cffe6a433", 0.902, 0.643, 0.2 end
  return "|cff7cc35a", 0.486, 0.765, 0.353
end
function PUN.num(v) v = tonumber(v); if not v then return nil end return math.floor(v + 0.5) end
function PUN.dif(d) if d > 0 then return "+" .. d end return tostring(d) end
function PUN.colDif(d) if d > 0 then return "|cff33ff66" elseif d < 0 then return "|cffff4d4d" end return "|cff999999" end
-- Lineas de "Si te la pones:" (puntuacion y estadisticas principales) o nil si no hay datos. item = itemID o enlace.
function PUN.simular(p, item, s, maxStats)
  if not (WowF.simularPieza and type(p) == "table" and item) then return nil end
  local ok, r = pcall(WowF.simularPieza, p, item, s)
  if not ok or type(r) ~= "table" then return nil end
  local a, d = PUN.num(r.antes), PUN.num(r.despues)
  if not a or not d then return nil end
  local l = { PUN.colDif(d - a) .. L("Puntuación: ", "Score: ") .. a .. " » " .. d .. " (" .. PUN.dif(d - a) .. ")|r" }
  local h = type(r.hueco) == "table" and r.hueco or nil
  local ha, hd = h and PUN.num(h.antes), h and PUN.num(h.despues)
  if ha and hd then table.insert(l, "|cff999999" .. L("Este hueco: ", "This slot: ") .. ha .. " » " .. hd .. " / 100|r") end
  local n = 0
  for _, st in ipairs(type(r.stats) == "table" and r.stats or {}) do
    if n >= (maxStats or PUN.MAX_STATS) then break end
    local nom = type(st) == "table" and (st.nombre or st[1]) or nil
    local sa, sd = type(st) == "table" and PUN.num(st.antes) or nil, type(st) == "table" and PUN.num(st.despues) or nil
    if type(nom) == "string" and sa and sd and sa ~= sd then
      n = n + 1
      table.insert(l, PUN.colDif(sd - sa) .. nom .. " " .. sa .. " » " .. sd .. " (" .. PUN.dif(sd - sa) .. ")|r")
    end
  end
  return l
end
-- Bloque para anadir al final de un tooltip de texto ("" si no hay datos)
function PUN.texto(p, item, s)
  local l = PUN.simular(p, item, s)
  if not l then return "" end
  return "\n \n|cffd8b468" .. L("Si te la pones:", "If you equip it:") .. "|r\n" .. table.concat(l, "\n")
end
WowF._equipoSimularLineas = PUN.simular -- para las pruebas
-- 16-oct: tooltip de una pieza recomendada = el del objeto (estadisticas reales) + de donde sale la mejora + nuestro texto.
-- texto puede empezar por el nombre: se quita para no repetirlo. Sin id o sin WowF.tooltipPieza = texto como antes.
function PUN.pieza(tt, p, id, s, texto, nombre)
  id = tonumber(id)
  texto = texto or ""
  if id and WowF.tooltipPieza then
    nombre = nombre or (obj(id))
    if type(nombre) == "string" and texto:sub(1, #nombre + 1) == nombre .. "\n" then texto = texto:sub(#nombre + 2) end
    local ok = pcall(WowF.tooltipPieza, tt, id, { nombre = Y(nombre or "?"), texto = Y(texto) })
    if ok then return end
  end
  tt:SetText(Y((nombre and (nombre .. "\n") or "") .. texto .. PUN.texto(p, id, s)), 1, 1, 1, 1, true)
end
-- Tooltip de la tarjeta de puntuacion: explicacion + una linea por hueco (como GearQuest), de peor a mejor
function PUN.ayudaPuntuacion(pu)
  return function(tt)
    local function linea(t, r, g, b) if tt.AddLine then tt:AddLine(Y(t), r or 1, g or 1, b or 1, true) end end
    tt:SetText(Y("|cffd8b468" .. L("Tu equipo para tu nivel", "Your gear for your level") .. "|r"), 1, 1, 1, 1, true)
    local ex
    if WowF.puntuacionExplicacion then
      local ok, r = pcall(WowF.puntuacionExplicacion, pu)
      if ok and type(r) == "table" and #r > 0 then ex = r end
    end
    if ex then for _, t in ipairs(ex) do if type(t) == "string" then linea(t) end end
    else linea((WowF.puntuacionFrase and WowF.puntuacionFrase(pu)) or SIN_DATOS()) end
    local det = type(pu) == "table" and type(pu.huecosDetalle) == "table" and pu.huecosDetalle or nil
    if det and #det > 0 then
      linea(" ")
      linea(L("Por hueco (de peor a mejor):", "By slot (worst to best):"), 0.847, 0.706, 0.408)
      for _, h in ipairs(det) do
        if type(h) == "table" then
          local nom = (h.slot and NOMBRE[h.slot] and nombreHueco(h.slot)) or h.nombre or "?"
          local pieza = h.pieza
          if type(pieza) == "table" then pieza = pieza.n or pieza.nombre end
          local izq, der, r, g, b
          if h.vacio then
            izq, der, r, g, b = nom, L("vacío", "empty"), 0.6, 0.6, 0.6
          else
            local _, cr, cg, cb = PUN.colorValor(h.valor)
            izq, der, r, g, b = nom .. ": " .. tostring(pieza or "?"), tostring(PUN.num(h.valor) or "?"), cr, cg, cb
          end
          if (tonumber(h.peso) or 1) > 1 then izq = izq .. " |cff999999" .. L("(cuenta doble)", "(counts double)") .. "|r" end
          if tt.AddDoubleLine then tt:AddDoubleLine(Y(izq), der, 1, 1, 1, r, g, b)
          else linea(izq .. "  " .. PUN.hex({ r, g, b }) .. der .. "|r") end
        end
      end
    end
    linea(" ")
    linea(L("El filtro Mostrar solo elige qué opciones ves; no cambia este número, el puesto (#) ni los huecos con mejora.",
      "The Show filter only picks which options you see; it does not change this number, the rank (#) or the slots with an upgrade."), 0.6, 0.6, 0.6)
    linea(L("Pasa el ratón por una pieza para ver cuánto subiría tu puntuación.", "Hover a piece to see how much your score would go up."), 0.6, 0.6, 0.6)
    linea(L("Clic: ver el hueco que más sube", "Click: show the slot that improves most"), 0.4, 0.8, 1)
  end
end
WowF._equipoAyudaPuntuacion = PUN.ayudaPuntuacion -- para las pruebas

-- Fabricada de tu plan para un hueco: la mas cercana a tu nivel que vale la pena (si) o es util (normal)
local function fabricadaDe(p, s, nivel)
  if WowF.mejorasDe and not WowF.mejorasDe("fabricar") then return nil end
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  local mejor, mejorV
  for _, e in ipairs(p.eventos or {}) do
    if e[2] == "equipo" and e.ra and SLOT[e.ra] == s and (e[1] or 0) >= nivel - 3 and (e[1] or 0) <= nivel + 5 and (e[1] or 0) <= tope then
      local v = "normal"
      if WowF.valeLaPena then local ok, r = pcall(WowF.valeLaPena, e); v = ok and r or "opcional" end
      if v == "si" or v == "normal" then
        local rank = (v == "si") and 0 or 1
        if not mejor or rank < mejorV or (rank == mejorV and e[1] < mejor[1]) then mejor, mejorV = e, rank end
      end
    end
  end
  if not mejor then return nil end
  local t = trozos(mejor[3])
  local nombre = (t[1] or ""):match("^(.-) %(.-%)$") or t[1] or "?"
  local prof = (t[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aún no disponible en WoW Forever; se actualizará)", "(level not yet available in WoW Forever; will be updated)"))
  return { e = mejor, v = mejorV == 0 and "si" or "normal", nombre = nombre, prof = prof }
end

-- Estado de cada casilla: ok | mejora | peq | nada
local function estados(p, g, nivel)
  local r = {}
  local cuenta = 0
  -- 13-oct: el estado sale de la puntuacion (sin filtro), asi Todo/Misiones/Mazmorras/Fabricar dicen lo mismo
  local okP, punt = pcall(function() return WowF.puntuacionEquipo and WowF.puntuacionEquipo(p) end)
  local ph = okP and type(punt) == "table" and punt.porHueco or nil
  for _, lista in ipairs({ IZQ, DER, ARMAS }) do
    for _, s in ipairs(lista) do
      local x = g and g.ranuras and g.ranuras[s]
      local fab = (not x) and fabricadaDe(p, s, nivel) or nil
      local pu = puesto(s)
      local est
      local h = ph and ph[s]
      if h and h.estado == "ok" then est = "ok"
      elseif h then est = (x and x.dudosa) and "peq" or "mejora"
      elseif x then est = x.dudosa and "peq" or "mejora"
      elseif fab then est = fab.v == "si" and "mejora" or "peq"
      elseif pu then est = "ok"
      else est = "nada" end
      if est == "mejora" or est == "peq" then cuenta = cuenta + 1 end
      r[s] = { est = est, x = x, fab = fab, pu = pu }
    end
  end
  return r, cuenta
end

local vista, sel
WowF.equipoElegir = function(s) sel = s end -- 12-oct: para las pruebas (elige el hueco que se muestra)

-- Icono del pool en su estado normal (los iconos se reutilizan entre casillas y tarjetas): borde de 1 px y opaco
local function icono(k, x, y, tam, tex, color, gris)
  local i = k:icono(x, y, tam, tex, color, gris)
  if i.negro and i.negro.ClearAllPoints then i.negro:ClearAllPoints(); i.negro:SetPoint("TOPLEFT", 1, -1); i.negro:SetPoint("BOTTOMRIGHT", -1, 1) end
  if i.SetAlpha then i:SetAlpha(1) end
  return i
end

-- Casilla: icono de 44 con borde segun estado + rotulo de 10 en mayusculas
local function casilla(k, x, y, s, info, elegida, ctx, ayuda)
  local est = info.est
  local cMejora, cOro = C().verde, C().oro
  if elegida then
    local aro = k:tarjeta(x + 9 - 3, y - 3, ICO + 6, ICO + 6, nil, cMejora, cMejora, true)
    if aro.SetBackdropColor then pcall(aro.SetBackdropColor, aro, cMejora[1], cMejora[2], cMejora[3], 0.3); pcall(aro.SetBackdropBorderColor, aro, cMejora[1], cMejora[2], cMejora[3], 0.3) end
  end
  local i = icono(k, x + 9, y, ICO, info.pu and info.pu.tex or nil, nil, false)
  local borde, grosor = BORDE_OK, 1
  if elegida or est == "mejora" then borde, grosor = cMejora, 2 elseif est == "peq" then borde, grosor = cOro, 2 end
  if i.borde and i.borde.SetColorTexture then i.borde:SetColorTexture(borde[1], borde[2], borde[3], 1) end
  if i.negro and i.negro.ClearAllPoints then
    i.negro:ClearAllPoints(); i.negro:SetPoint("TOPLEFT", grosor, -grosor); i.negro:SetPoint("BOTTOMRIGHT", -grosor, grosor)
  end
  if not (info.pu and info.pu.tex) and i.tex and i.tex.SetColorTexture then i.tex:SetColorTexture(VACIA[1], VACIA[2], VACIA[3], 1) end
  if i.SetAlpha then i:SetAlpha(est == "nada" and not elegida and 0.55 or 1) end
  local fs = k:texto(x - 10, y + ICO + 2, E().mayus(nombreHueco(s)), { tam = 12, peso = "negrita", ancho = CAS_W + 20, just = "CENTER" }) -- 12-oct: con la letra mas grande "MAIN HAND" se cortaba
  E().letra(fs, "cuerpoNegrita", 10)
  local color = C().apagado
  if elegida or est == "mejora" then color = cMejora elseif est == "peq" then color = cOro end
  fs:SetTextColor(color[1], color[2], color[3], 1)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  k:zona(x, y, CAS_W, CAS_H, function()
    sel = s
    if ctx and ctx.redibujar then ctx.redibujar() end
  end, ayuda)
end

-- Silueta del personaje con rectangulos (WoW no recorta poligonos): cabeza, cuello, torso, brazos y piernas
local PIEZAS_SIL = { { 46, 0, 28, 34 }, { 52, 30, 16, 10 }, { 28, 40, 64, 52 }, { 31, 90, 58, 95 }, { 8, 46, 22, 108 }, { 90, 46, 22, 108 },
  { 34, 185, 24, 145 }, { 62, 185, 24, 145 } }
local function silueta(k, x0, y0)
  for _, r in ipairs(PIEZAS_SIL) do
    local t = k:tomar("sil", k.capa, function(pd) return pd:CreateTexture(nil, "BACKGROUND", nil, 1) end)
    if t.SetColorTexture then t:SetColorTexture(SILUETA[1], SILUETA[2], SILUETA[3], 1) end
    t:SetSize(r[3], r[4])
    t:SetPoint("TOPLEFT", k.marco, "TOPLEFT", x0 + r[1], -(y0 + r[2]))
  end
end

-- 11-oct (Andy: "trae de vuelta el personaje 3D"): PlayerModel con tu personaje; arrastrar con el raton lo gira.
-- Se crea una vez (vista.modelo) y se recoloca en cada dibujo. Sin PlayerModel (o si falla) = false y se dibuja la silueta.
local function modelo3D(k, x, y, w, h)
  if vista.modelo == nil then
    vista.modelo = false
    if type(CreateFrame) == "function" then
      local ok, md = pcall(CreateFrame, "PlayerModel", nil, k.marco)
      if ok and type(md) == "table" then
        vista.modelo = md
        pcall(function()
          md:EnableMouse(true)
          local girando
          md:SetScript("OnMouseDown", function() girando = GetCursorPosition and GetCursorPosition() end)
          md:SetScript("OnMouseUp", function() girando = nil end)
          md:SetScript("OnHide", function() girando = nil end)
          md:SetScript("OnUpdate", function(self)
            if type(girando) ~= "number" or not GetCursorPosition then return end
            local cx = GetCursorPosition()
            if type(cx) == "number" and self.SetFacing and self.GetFacing then self:SetFacing((tonumber(self:GetFacing()) or 0) + (cx - girando) / 80) end
            girando = cx
          end)
        end)
      end
    end
  end
  local md = vista.modelo
  if not md then return false end
  local ok = pcall(function()
    md:ClearAllPoints()
    md:SetPoint("TOPLEFT", k.marco, "TOPLEFT", x, -y)
    md:SetSize(w, h)
    md:SetFrameLevel((tonumber(k.marco:GetFrameLevel()) or 0) + 20)
    local cara = md.GetFacing and tonumber(md:GetFacing())
    md:SetUnit("player")
    if cara and md.SetFacing then md:SetFacing(cara) end
    md:Show()
  end)
  return ok
end

local function ayudaCasilla(s, info, pu, nivel, p)
  return function(tt)
    local l = { "|cffd8b468" .. nombreHueco(s) .. "|r" }
    table.insert(l, info.pu and (L("Llevas: ", "Wearing: ") .. info.pu.nombre) or ("|cff999999" .. L("Ranura vacía", "Empty slot") .. "|r"))
    local h = pu and pu.porHueco and pu.porHueco[s]
    if h then table.insert(l, L("Puntuación del hueco: ", "Slot score: ") .. PUN.colorValor(h.valor) .. math.floor(h.valor + 0.5) .. "|r / 100") end
    if WowF.rangoHueco then
      local ok, r = pcall(WowF.rangoHueco, s)
      if ok and type(r) == "table" and r.texto then
        table.insert(l, "|cff999999" .. r.texto .. "|r")
        -- 13-oct: el puesto (#) se cuenta con lo que muestra el filtro; la puntuacion no
        if r.rango then table.insert(l, "|cff999999" .. L("(el puesto # es entre todo lo verificado que ya puedes usar; el filtro no lo cambia)", "(the # rank is among everything verified you can already use; the filter does not change it)") .. "|r") end
      end
    end
    if info.x and WowF.equipoAyuda then table.insert(l, " "); table.insert(l, WowF.equipoAyuda(info.x, nivel))
    elseif info.fab then
      table.insert(l, "|cff33ff66" .. L("Te la fabricas: ", "You craft it: ") .. info.fab.nombre .. "|r")
      table.insert(l, "|cff999999" .. info.fab.prof .. "|r")
    end
    -- 13-oct: simular la siguiente mejora del hueco
    local item = (info.x and info.x.id) or (info.fab and info.fab.e and info.fab.e.i) or nil
    table.insert(l, "|cff66ccff" .. L("Clic: ver este hueco", "Click: show this slot") .. "|r")
    if item then PUN.pieza(tt, p, item, s, table.concat(l, "\n"), (info.x and (obj(info.x.id))) or (info.fab and info.fab.nombre)) return end
    tt:SetText(Y(table.concat(l, "\n")), 1, 1, 1, 1, true)
  end
end

-- ===== Izquierda: "Lo que llevas" =====
local function muneco(k, p, g, est, cuenta, nivel, ctx, pu)
  local card = k:tarjeta(0, 0, MUNECO_W, ALTO_BASE, nil, MUNECO, C().borde)
  k:rotulo(16, 17, L("Lo que llevas", "What you wear"), C().oro)
  local dx = MUNECO_W - 16
  for _, c in ipairs({ { L("Bien así", "Fine"), "gris" }, { L("Pequeña", "Small"), "oro" }, { L("Mejora", "Upgrade"), "verde" } }) do
    local _, w = k:chip(dx, 14, c[1], c[2], true)
    dx = dx - w - 6
  end
  local top = 48
  local altoCol = #IZQ * CAS_H + (#IZQ - 1) * CAS_GAP
  for i, s in ipairs(IZQ) do casilla(k, 16, top + (i - 1) * (CAS_H + CAS_GAP), s, est[s], sel == s, ctx, ayudaCasilla(s, est[s], pu, nivel, p)) end
  for i, s in ipairs(DER) do casilla(k, MUNECO_W - 16 - CAS_W, top + (i - 1) * (CAS_H + CAS_GAP), s, est[s], sel == s, ctx, ayudaCasilla(s, est[s], pu, nivel, p)) end
  -- Figura
  local fx, fw = 16 + COL_W + 6, MUNECO_W - 32 - 2 * COL_W - 12
  k:tarjeta(fx, top, fw, altoCol, nil, FIGURA, FIGURA_BORDE, true)
  -- 11-oct (Andy: "Tu equipo: 1/100 no se entiende"): que diga QUE mide y que es el 100
  local yMod = top + 8
  if type(pu) == "table" and type(pu.total) == "number" then
    local v = math.max(0, math.min(100, math.floor(pu.total + 0.5)))
    local cod, br, bg, bb = PUN.colorValor(v)
    k:texto(fx, top + 6, L("Tu equipo para tu nivel", "Your gear for your level"), { tam = 11, color = C().tenue, ancho = fw, just = "CENTER" })
    k:texto(fx, top + 19, cod .. v .. " |r" .. L("de 100", "out of 100"), { tam = 15, peso = "negrita", ancho = fw, just = "CENTER" })
    -- 13-oct: la palabra (Flojo/Regular/Bueno/Excelente) con su color, de WowF.puntuacionEquipo
    local yb = top + 38
    if type(pu.palabra) == "string" and pu.palabra ~= "" then
      local pc = type(pu.color) == "table" and { tonumber(pu.color[1] or pu.color.r) or br, tonumber(pu.color[2] or pu.color.g) or bg, tonumber(pu.color[3] or pu.color.b) or bb } or { br, bg, bb }
      k:texto(fx, top + 37, Y(pu.palabra), { tam = 12, peso = "negrita", color = pc, ancho = fw, just = "CENTER" })
      yb = top + 55
    end
    local b = k:barra(fx + 14, yb, fw - 28, v, 100)
    if b and b.relleno and b.relleno.SetColorTexture then b.relleno:SetColorTexture(br, bg, bb, 1) end
    local nH = tonumber(pu.cuenta) or (type(pu.huecosDetalle) == "table" and #pu.huecosDetalle) or nil
    local _, hNota = k:texto(fx, yb + 8, nH and L("Media de " .. nH .. " huecos · los filtros no la cambian", "Average of " .. nH .. " slots · filters do not change it")
      or L("Los filtros no la cambian", "Filters do not change it"), { tam = 10, color = C().apagado, ancho = fw, just = "CENTER" })
    yMod = yb + 8 + (tonumber(hNota) or 13) + 6
    -- Raton: de donde sale la puntuacion y cada hueco; clic: el hueco que mas sube
    k:zona(fx, top, fw, yMod - top - 2, function() if pu and pu.peor then sel = pu.peor; if ctx.redibujar then ctx.redibujar() end end end,
      PUN.ayudaPuntuacion(pu))
  end
  local hMod = top + altoCol - 30 - yMod
  if not modelo3D(k, fx + 3, yMod, fw - 6, hMod) then
    silueta(k, fx + math.floor((fw - 120) / 2), top + 60)
  else
    k:texto(fx, top + altoCol - 10 - 15 - 15, L("arrastra para girar", "drag to rotate"), { tam = 10, color = C().apagado, ancho = fw, just = "CENTER" })
  end
  local frase = L("Nivel " .. nivel .. " · " .. cuenta .. (cuenta == 1 and " hueco con mejora" or " huecos con mejora"),
    "Level " .. nivel .. " · " .. cuenta .. (cuenta == 1 and " slot with an upgrade" or " slots with an upgrade"))
  k:texto(fx, top + altoCol - 10 - 15, frase, { tam = 12, color = C().tenue, ancho = fw, just = "CENTER" })
  -- Armas
  local ay = top + altoCol + 10
  local ancho = #ARMAS * CAS_W + (#ARMAS - 1) * 20
  local ax = math.floor((MUNECO_W - ancho) / 2)
  for i, s in ipairs(ARMAS) do casilla(k, ax + (i - 1) * (CAS_W + 20), ay, s, est[s], sel == s, ctx, ayudaCasilla(s, est[s], pu, nivel, p)) end
  return card
end

-- Caja de dato (2 columnas): rotulo de color + texto de 13
local function dato(k, x, y, w, rotulo, texto, color)
  local caja = k:tarjeta(x, y, w, 40, nil, (WowF.vistaKit.CASILLA), (WowF.vistaKit.CASILLA_BORDE), true)
  k:rotulo(x + 10, y + 8, rotulo, color or C().verde)
  local _, h = k:texto(x + 10, y + 8 + 15, texto, { tam = 13, ancho = w - 20 })
  return caja, 8 + 15 + h + 8
end

-- Como fabricarla: receta y materiales al chat
local function decirFabricar(fab)
  local e = fab.e
  local mats = {}
  for _, m in ipairs(e.m or {}) do
    local tn = (GetItemCount and llamar(GetItemCount, m[1], true)) or 0
    table.insert(mats, (m[2] or "?") .. " " .. (m[3] or "?") .. ((tonumber(tn) or 0) > 0 and L(" (tienes " .. tn .. ")", " (you have " .. tn .. ")") or ""))
  end
  print(Y("|cff33ccffForever Guide|r: " .. fab.nombre .. " · " .. fab.prof .. " · " .. L("pide nivel ", "requires level ") .. (e[1] or "?")))
  if #mats > 0 then print(Y("|cff33ccffForever Guide|r: " .. L("Materiales: ", "Materials: ") .. table.concat(mats, ", "))) end
end

-- ===== Derecha: filtro, siguiente mejora, BiS 30 y mazmorra =====
-- 11-oct (Andy: "dos filas de filtros es muy confuso"): UNA fila exclusiva Todo · Misiones · Mazmorras · Fabricar · Comprar
-- (WowF.ponerEstiloEquipo en wowF_EquipoGuia.lua). Las casillas de Ajustes siguen aparte; si apagan algo, sale su aviso debajo.
local FILA = {
  { "todo", function() return L("Todo", "All") end, function() return L("Todas las mejoras: misiones, mazmorras y lo que te fabricas.", "All upgrades: quests, dungeons and crafting.") end },
  { "soloMisiones", function() return L("Misiones", "Quests") end, function() return L("Solo mejoras que te dan las misiones.", "Only upgrades from quests.") end },
  { "soloMazmorras", function() return L("Mazmorras", "Dungeons") end, function() return L("Solo mejoras que caen en mazmorras.", "Only upgrades that drop in dungeons.") end },
  { "soloFabricar", function() return L("Fabricar", "Crafting") end, function() return L("Solo lo que te fabricas con tus profesiones.", "Only what you craft with your professions.") end },
  { "comprar", function() return L("Comprar", "Buy") end, function() return L("Piezas de vendedor de la guía BiS de tu facción. Casa de subastas: aún no hay datos de WoW Forever; pendiente de actualizar.", "Vendor pieces from the BiS guide for your faction. Auction house: no WoW Forever data yet; pending update.") end },
}
local function filtro(k, x0, ctx)
  if not WowF.estiloEquipo then return 0 end
  local _, _, w = k:texto(x0, 3, L("Mostrar", "Show"), { tam = 12, color = C().tenue })
  local x = x0 + (w or 50) + 8
  local actual = WowF.estiloEquipo()
  if actual == "sinMazmorras" or actual == "yaPuedo" then actual = "todo" end -- guardados viejos
  for _, e in ipairs(FILA) do
    local on = actual == e[1]
    local _, cw = k:chip(x, 0, e[2](), on and "verde" or "neutro")
    local clave = e[1]
    k:zona(x, 0, cw or 80, 20, function()
      if WowF.ponerEstiloEquipo then WowF.ponerEstiloEquipo(clave) end
      if ctx.redibujar then ctx.redibujar() end
    end, e[3]())
    x = x + (cw or 80) + 6
  end
  local y = 20
  if WowF.avisoFiltroMejoras then
    local ok, a = pcall(WowF.avisoFiltroMejoras)
    if ok and type(a) == "string" and a ~= "" then
      local _, h = k:texto(x0, y + 6, Y(a), { tam = 12, ancho = ctx.anchoFiltro or 478 })
      y = y + 6 + h
    end
  end
  return y
end

-- 12-oct (Andy): "Ver otras opciones (N)" bajo la mejor del hueco. Origenes: Mision / Linea de misiones / Mazmorra
-- (WowF.equipoGuia -> g.otras[slot], ya filtradas por Ajustes y por el filtro Mostrar), Fabricar (p.eventos, misma regla que
-- fabricadaDe) y Comprar (vendedores de la guia BiS de tu faccion, WowF.equipoVendedores; solo con Mostrar: Todo).
-- Estado desplegado por hueco en WowFExportarDB.equipoOtras[slot] (si no hay DB, solo esta sesion). Todo en una tabla: tope de locales.
local OPC = { sesion = {}, MAX = 10,
  CAL = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" } }
function OPC.abierta(s)
  if type(WowFExportarDB) == "table" and type(WowFExportarDB.equipoOtras) == "table" then return WowFExportarDB.equipoOtras[s] == true end
  return OPC.sesion[s] == true
end
function OPC.cambiar(s)
  local v = not OPC.abierta(s)
  if type(WowFExportarDB) == "table" then
    if type(WowFExportarDB.equipoOtras) ~= "table" then WowFExportarDB.equipoOtras = {} end
    WowFExportarDB.equipoOtras[s] = v or nil
  end
  OPC.sesion[s] = v or nil
end
function OPC.color(q, n) return (OPC.CAL[tonumber(q) or 1] or OPC.CAL[1]) .. tostring(n or "?") .. "|r" end
-- Lista de alternativas del hueco s: { { origen, x = recompensa | fab = fabricada | pz = pieza de vendedor } }
function OPC.lista(s, info, nivel, g, p, dBis)
  local r = {}
  local mejor = info and info.x
  for _, x in ipairs((g and g.otras and g.otras[s]) or {}) do
    if x ~= mejor then
      local origen = (x.tipo == "mazmorra") and "mazmorra" or ((WowF.equipoLinea and WowF.equipoLinea(x)) and "linea" or "mision")
      r[#r + 1] = { origen = origen, x = x }
    end
  end
  if not (WowF.mejorasDe and not WowF.mejorasDe("fabricar")) then
    local tope = (WowFDatos and WowFDatos.topeBeta) or 30
    local yaFab = info and info.fab and info.fab.e
    for _, e in ipairs(p.eventos or {}) do
      if e ~= yaFab and e[2] == "equipo" and e.ra and SLOT[e.ra] == s and (e[1] or 0) >= nivel - 3 and (e[1] or 0) <= nivel + 5 and (e[1] or 0) <= tope then
        local v = "normal"
        if WowF.valeLaPena then local ok, rv = pcall(WowF.valeLaPena, e); v = ok and rv or "opcional" end
        if v == "si" or v == "normal" then
          local t = trozos(e[3])
          local prof = (t[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aún no disponible en WoW Forever; se actualizará)", "(level not yet available in WoW Forever; will be updated)"))
          r[#r + 1] = { origen = "fabricar", fab = { e = e, v = v, nombre = (t[1] or ""):match("^(.-) %(.-%)$") or t[1] or "?", prof = prof } }
        end
      end
    end
    -- 12-oct (b): tambien lo que se fabrica con OTRAS profesiones (aunque no las tengas, se dice), la mejor de cada una
    local ok, l = pcall(OPC.fabricarOtras, s, info, nivel, p, r)
    for _, o in ipairs((ok and type(l) == "table") and l or {}) do r[#r + 1] = o end
  end
  local estilo = WowF.estiloEquipo and WowF.estiloEquipo() or "todo"
  if (estilo == "todo" or estilo == "sinMazmorras" or estilo == "yaPuedo") and WowF.equipoVendedores then
    local ok, l = pcall(WowF.equipoVendedores, s, p, dBis)
    for _, e in ipairs((ok and type(l) == "table") and l or {}) do
      if not (estilo == "yaPuedo" and (e.pz.nv or 0) > nivel) then r[#r + 1] = { origen = "comprar", pz = e.pz, hueco = e.hueco } end
    end
  end
  -- 12-oct (b): casa de subastas SOLO con precio real (Auctionator, TSM o lo que viste tu; WowF.precioSubasta de wowF_AvisoBotin).
  -- Nunca un precio inventado: sin precio, no sale.
  if estilo == "todo" or estilo == "comprar" then
    local vistos = {}
    for _, o in ipairs(r) do
      local id = (o.x and o.x.id) or (o.fab and o.fab.e.i) or (o.pz and o.pz.id)
      if id and not vistos[id] and WowF.precioSubasta then
        vistos[id] = true
        local okp, precio, fuente, edad = pcall(WowF.precioSubasta, nil, id)
        if okp and tonumber(precio) and precio > 0 then r[#r + 1] = { origen = "subasta", id = id, precio = precio, fuente = fuente, edad = edad, base = o } end
      end
    end
  end
  -- Al menos una por origen arriba (la mejor de cada uno, en el orden en que llegan); luego el resto
  local primero, resto, ya = {}, {}, {}
  for _, o in ipairs(r) do
    o.mejorX = info and info.x or nil
    if not ya[o.origen] then ya[o.origen] = true; primero[#primero + 1] = o else resto[#resto + 1] = o end
  end
  for _, o in ipairs(resto) do primero[#primero + 1] = o end
  return primero
end
-- Piezas que se fabrican con profesiones que no son las de tu plan (WowFDatos.clases[clase].ramas[rama].equipo[prof]: ya filtradas
-- para tu clase y tu rama por el generador; hasta = 0 = no es de tu rama). La mejor de cada profesion para el hueco s, que pida
-- como mucho nivel + 5 (y el tope de la beta) y que aun te dure. Sin repetir lo que ya sale.
function OPC.fabricarOtras(s, info, nivel, p, ya)
  local D = WowFDatos
  local c = D and D.clases and p and p.clase and D.clases[p.clase]
  local rama = c and c.ramas and c.ramas[p.indiceRama or 0]
  if not (rama and rama.equipo) then return {} end
  local tope = D.topeBeta or 30
  local visto, mias = {}, {}
  for _, o in ipairs(ya or {}) do if o.fab and o.fab.e.i then visto[o.fab.e.i] = true end end
  if info and info.fab and info.fab.e then visto[info.fab.e.i or -1] = true end
  if info and info.x then visto[info.x.id or -1] = true end
  for _, id in ipairs(p.tengo or {}) do mias[id] = true end
  local vacia = not llamar(GetInventoryItemLink, "player", s)
  local res = {}
  for prof, lista in pairs(rama.equipo) do
    if not (D.recoleccion and D.recoleccion[prof]) then
      local mejor
      for _, e in ipairs(lista) do
        local inv = e[4]
        if SLOT[inv] == s and not visto[e[2]] and (e[7] or 60) ~= 0 and (e[1] or 0) <= nivel + 5 and (e[1] or 0) <= tope
          and (vacia or (e[7] or 60) > nivel) and (not mejor or (e[3] or 0) > (mejor[3] or 0)) then
          mejor = e
        end
      end
      if mejor then
        local n, q, ic = obj(mejor[2])
        local mats = {}
        for _, m in ipairs(mejor[6] or {}) do local mn, _, mic = obj(m[1]); mats[#mats + 1] = { m[1], m[2], mn, mic } end
        local ev = { mejor[1], "equipo", mejor[5], i = mejor[2], q = q, ic = ic, m = mats, ra = mejor[4], hasta = mejor[7] or 60, puntos = mejor[3] }
        local v = "normal"
        if WowF.valeLaPena then local ok, rv = pcall(WowF.valeLaPena, ev); v = ok and rv or "opcional" end
        if v ~= "ya" then
          visto[mejor[2]] = true
          local t = trozos(mejor[5])
          local pr = (t[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aún no disponible en WoW Forever; se actualizará)", "(level not yet available in WoW Forever; will be updated)"))
          local nombreProf = (D.prof and D.prof[prof]) or pr
          res[#res + 1] = { origen = "fabricar", orden = mejor[3] or 0, fab = { e = ev, v = (v == "si") and "si" or "normal", nombre = (t[1] or ""):match("^(.-) %(.-%)$") or t[1] or n,
            prof = pr, profId = prof, noLaTienes = not mias[prof], nombreProf = nombreProf } }
        end
      end
    end
  end
  table.sort(res, function(a, b) return a.orden > b.orden end)
  return res
end
-- Comparacion corta con la mejor del hueco: "un poco peor que X", "peor que X", "parecida a X", "mejor que X, pero desde nivel N"
function OPC.vsMejor(ratio, mejorId, desde, nivel)
  if not ratio or not mejorId then return nil end
  local n = obj(mejorId)
  if ratio >= 1.05 then
    if (desde or 0) > nivel then return L("mejor que " .. n .. ", pero desde nivel " .. desde, "better than " .. n .. ", but from level " .. desde) end
    return L("mejor que " .. n, "better than " .. n)
  end
  if ratio >= 0.95 then return L("parecida a " .. n, "similar to " .. n) end
  if ratio >= 0.8 then return L("un poco peor que " .. n, "a bit worse than " .. n) end
  return L("peor que " .. n, "worse than " .. n)
end
OPC.CHIP = {
  mision = { function() return L("Misión", "Quest") end, "oro" },
  linea = { function() return L("Línea de misiones", "Questline") end, "brasa" },
  mazmorra = { function() return L("Mazmorra", "Dungeon") end, "gris" },
  fabricar = { function() return L("Fabricar", "Crafting") end, "verde" },
  comprar = { function() return L("Comprar", "Buy") end, "neutro" },
  subasta = { function() return L("Subasta", "Auction") end, "neutro" },
}
-- Textos de una alternativa: nombre (color de calidad), que mejora / de donde sale, tooltip y accion (como "Llevame" de la mejor)
function OPC.datos(o, nivel)
  if o.x then
    local x = o.x
    local n, q = obj(x.id)
    local mejora = x.vacia and (x.porqueCorto or L("la ranura está vacía", "the slot is empty")) or ((WowF.equipoPorcentaje and WowF.equipoPorcentaje(x) or "") .. (x.porqueCorto and (" · " .. x.porqueCorto) or ""))
    if x.dudosa then mejora = L("Mejora pequeña", "Small upgrade") .. (mejora ~= "" and (" · " .. mejora) or "") end
    local vs = OPC.vsMejor(x.vsMejor, x.mejorId, x.desde, nivel)
    local cuando = ((x.desde or 0) > nivel) and (L("desde nivel ", "from level ") .. x.desde) or L("ya puedes", "available now")
    local sub = mejora .. (vs and (" · " .. vs) or "") .. "\n" .. (WowF.equipoFuente and WowF.equipoFuente(x) or "") .. " · " .. cuando
    local clic = (x.tipo == "mazmorra") and L("Clic: te llevo a la mazmorra", "Click: I take you to the dungeon")
      or ((o.origen == "linea") and L("Clic: te guío paso a paso desde la primera misión de la línea", "Click: I guide you step by step from the first quest of the line") or L("Clic: te llevo a quien da la misión", "Click: I take you to the quest giver"))
    local ayuda = (WowF.equipoAyuda and WowF.equipoAyuda(x, nivel)) or n
    return OPC.color(q, n), sub, ayuda .. "\n|cff66ccff" .. clic .. "|r", function() if WowF.irARecompensa then WowF.irARecompensa(x) end end, iconoObj(select(3, obj(x.id)), x.id)
  elseif o.fab then
    local f = o.fab
    local _, q = obj(f.e.i)
    local mx = o.mejorX
    local vs = (mx and f.e.puntos) and OPC.vsMejor((mx.puntos or 0) > 0 and (f.e.puntos / mx.puntos) or nil, mx.id, f.e[1], nivel) or nil
    local tiene = f.noLaTienes and L(" (no la tienes: hay que aprenderla y subirla)", " (you do not have it: learn it and level it up)") or ""
    local cuando = ((f.e[1] or 0) > nivel) and (L("desde nivel ", "from level ") .. f.e[1]) or (L("pide nivel ", "requires level ") .. (f.e[1] or "?"))
    local sub = ((f.v == "si") and L("Vale la pena", "Worth it") or L("Útil", "Useful")) .. (vs and (" · " .. vs) or "") .. "\n" .. L("Fabricar: ", "Craft: ") .. f.prof .. tiene .. " · " .. cuando
    return OPC.color(f.e.i and q or 2, f.nombre), sub, f.nombre .. "\n" .. f.prof .. "\n|cff66ccff" .. L("Clic: receta y materiales en el chat", "Click: recipe and materials in the chat") .. "|r",
      function() decirFabricar(f) end, iconoObj(f.e.ic, f.e.i)
  end
  if o.origen == "subasta" then
    local n, q, ic = obj(o.id)
    local din = (WowF.avisoBotinDinero and WowF.avisoBotinDinero(o.precio)) or tostring(o.precio)
    local de = (o.fuente == "visto") and L("lo viste tú", "you saw it") or tostring(o.fuente or "?")
    local sub = L("En la casa de subastas: ", "At the auction house: ") .. din .. " (" .. de .. (o.edad and (", " .. o.edad) or "") .. ")"
      .. "\n" .. L("El precio cambia: míralo antes de comprar.", "Prices change: check before buying.")
    local b = o.base
    return OPC.color(q, n), sub, n .. "\n" .. sub, function() if b then local _, _, _, acc = OPC.datos(b, nivel); if acc then acc() end end end, iconoObj(ic, o.id)
  end
  local pz = o.pz
  local sub = L("Pieza de vendedor de la guía BiS (", "Vendor piece from the BiS guide (") .. tostring(o.hueco or "?") .. ")"
    .. "\n" .. (((pz.nv or 0) > nivel) and (L("desde nivel ", "from level ") .. pz.nv) or (pz.nv and L("ya puedes", "available now") or L("nivel por confirmar", "level to be confirmed")))
    .. ((pz.ok == false) and (" · " .. L("sin confirmar: se actualizará", "not confirmed: it will be updated")) or "")
    .. "\n" .. L("Precio: aún no hay datos de WoW Forever; míralo en el vendedor.", "Price: no WoW Forever data yet; check it at the vendor.")
  return OPC.color(pz.q, pz.n), sub, tostring(pz.n or "?") .. "\n" .. ((WowF.bisComo and WowF.bisComo(pz)) or "") .. "\n|cff66ccff" .. L("Clic: te llevo al vendedor", "Click: I take you to the vendor") .. "|r",
    function() if WowF.irABiS then WowF.irABiS(pz) end end, iconoObj(nil, pz.id)
end
-- Seccion bajo los botones de la tarjeta de mejora. Devuelve la nueva y.
function OPC.seccion(k, x0, y, w, s, info, nivel, ctx, g, p, dBis)
  local lista = OPC.lista(s, info, nivel, g, p, dBis)
  local hayMejor = info and (info.x or info.fab)
  if #lista == 0 then
    if not hayMejor then return y end
    local _, h = k:texto(x0 + 16, y, L("No hay otras opciones verificadas en WoW Forever para este hueco.", "No other verified WoW Forever options for this slot."), { tam = 12, color = C().tenue, ancho = w - 32 })
    return y + h + 12
  end
  local abierta = OPC.abierta(s)
  local txt = abierta and L("Ocultar otras opciones", "Hide other options") or (L("Ver otras opciones (", "See other options (") .. #lista .. ")")
  k:boton(x0 + 16, y, txt, "terciario", true, function() OPC.cambiar(s); if ctx.redibujar then ctx.redibujar() end end,
    { ayuda = L("Otras piezas para este hueco, con de dónde salen: misión, línea de misiones, mazmorra, fabricar o comprar. Arriba queda la mejor.", "Other pieces for this slot and where they come from: quest, questline, dungeon, crafting or buying. The best one stays on top.") })
  y = y + 18 + 10
  if not abierta then return y end
  local _, ha = k:texto(x0 + 16, y, L("Clic en una opción: te llevo a ella. El filtro Mostrar elige qué orígenes salen.", "Click an option: I take you to it. The Show filter picks which sources appear."), { tam = 12, color = C().tenue, ancho = w - 32 })
  y = y + ha + 8
  for i, o in ipairs(lista) do
    if i > OPC.MAX then break end
    local nombre, sub, ayuda, accion, tex = OPC.datos(o, nivel)
    local ch = OPC.CHIP[o.origen]
    icono(k, x0 + 16, y, 28, tex, nil, false)
    local tx = x0 + 16 + 28 + 10
    local _, cw = k:chip(tx, y, ch[1](), ch[2])
    local _, hn = k:texto(tx + (cw or 60) + 8, y + 2, nombre, { tam = 13, peso = "negrita", ancho = x0 + w - 16 - (tx + (cw or 60) + 8) })
    local yl = y + math.max(20, hn) + 2
    local _, hs = k:texto(tx, yl, Y(sub), { tam = 12, color = C().tenue, ancho = x0 + w - 16 - tx })
    local alto = math.max(28, yl - y + hs)
    local idSim = (o.x and o.x.id) or (o.fab and o.fab.e and o.fab.e.i) or o.id or (o.pz and o.pz.id)
    k:zona(x0 + 16, y, w - 32, alto, accion, function(tt) PUN.pieza(tt, p, idSim, s, ayuda) end)
    y = y + alto + 10
  end
  if #lista > OPC.MAX then
    local _, hm = k:texto(x0 + 16, y, L("Mostrando " .. OPC.MAX .. " de " .. #lista .. ". Usa el filtro Mostrar para ver solo un origen.", "Showing " .. OPC.MAX .. " of " .. #lista .. ". Use the Show filter to see one source only."), { tam = 12, color = C().tenue, ancho = w - 32 })
    y = y + hm + 8
  end
  return y + 4
end

local function tarjetaMejora(k, x0, y0, w, s, info, nivel, ctx, pu, g, p, dBis)
  local card = k:tarjeta(x0, y0, w, 10, "principal")
  local ix, tx = x0 + 16, x0 + 16 + 52 + 14
  local tw = x0 + w - 16 - tx
  local x, fab = info.x, info.fab
  local hueco = nombreHueco(s)
  local y = y0 + 12 + 2
  local eti
  if x or fab then
    eti = hueco .. " · " .. (info.pu and (L("llevas ", "wearing ") .. info.pu.nombre) or L("ranura vacía", "empty slot"))
  else
    eti = hueco .. " · " .. (info.pu and L("bien así", "fine") or L("ranura vacía", "empty slot"))
  end
  k:rotulo(ix, y, eti)
  -- Puesto entre lo que puedes tener ya (WowF.rangoHueco)
  local rg
  if WowF.rangoHueco then local ok, r = pcall(WowF.rangoHueco, s); if ok and type(r) == "table" then rg = r end end
  if rg and rg.rango and info.pu then -- 11-oct: en una ranura vacia no hay "lo tuyo"
    k:chip(x0 + w - 16, y - 2, rg.rango == 1 and L("La #1 a tu nivel", "#1 at your level") or L("Lo tuyo: #" .. rg.rango, "Yours: #" .. rg.rango), rg.rango == 1 and "verde" or "gris", true)
  end
  y = y + 14 + 10
  local nombre, q, ic, sub, color
  if x then
    nombre, q, ic = obj(x.id)
    ic = iconoObj(ic, x.id)
    sub = L("Sale de: ", "Source: ") .. (WowF.equipoFuente and WowF.equipoFuente(x) or "") .. (((x.nivel or 0) > nivel) and (L(" · pide nivel ", " · requires level ") .. x.nivel) or "")
    color = x.dudosa and "oro" or "verde"
  elseif fab then
    nombre = fab.nombre
    ic = iconoObj(fab.e.ic, fab.e.i)
    sub = L("Sale de: ", "Source: ") .. fab.prof .. L(" · pide nivel ", " · requires level ") .. (fab.e[1] or "?")
    color = fab.v == "si" and "verde" or "oro"
  else
    nombre = info.pu and info.pu.nombre or L("Hueco vacío", "Empty slot")
    ic = info.pu and info.pu.tex or nil
    sub = (rg and rg.texto) or L("No hay nada verificado mejor para este hueco a tu nivel. Vuelve al subir de nivel.", "Nothing verified is better for this slot at your level. Check again when you level up.")
  end
  local ico = icono(k, ix, y, 52, ic, color, false)
  if not ic and ico.tex and ico.tex.SetColorTexture then ico.tex:SetColorTexture(VACIA[1], VACIA[2], VACIA[3], 1) end
  local ty = y
  local colEti = (color == "oro") and C().oro or ((color == "verde") and C().verde or C().tenue)
  k:rotulo(tx, ty, (x or fab) and ((color == "oro") and L("Mejora pequeña", "Small upgrade") or L("Siguiente mejora", "Next upgrade")) or L("Bien así", "Fine"), colEti)
  ty = ty + 16
  local _, h2 = k:texto(tx, ty, nombre, { tam = 22, letra = "marca", ancho = tw })
  ty = ty + h2 + 4
  local _, hs = k:texto(tx, ty, Y(sub), { tam = 13, color = C().tenue, ancho = tw })
  ty = ty + hs
  -- 16-oct (Andy: "le pongo el mouse y no dice nada"): ratón sobre la pieza = estadísticas reales + de dónde sale la mejora
  if x or fab then
    local idP = (x and x.id) or (fab and fab.e and fab.e.i)
    local ayM = x and ((WowF.equipoAyuda and WowF.equipoAyuda(x, nivel)) or "") or ("|cff999999" .. sub .. "|r")
    k:zona(ix, y, w - 32, math.max(52, ty - y), function() if x then if WowF.irARecompensa then WowF.irARecompensa(x) end else decirFabricar(fab) end end,
      function(tt) PUN.pieza(tt, p, idP, s, ayM, nombre) end)
  end
  y = math.max(y + 52, ty) + 14
  -- Datos en 2 columnas
  local dw = math.floor((w - 32 - 10) / 2)
  local r1, t1, r2, t2, c1
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  if x then
    r1 = x.dudosa and L("Mejora pequeña", "Small upgrade") or L("Vale la pena", "Worth it")
    c1 = x.dudosa and C().oro or C().verde
    t1 = x.hasta and L("te dura hasta el nivel " .. x.hasta, "lasts until level " .. x.hasta) or L("nada mejor verificado hasta el nivel " .. (x.tope or tope), "nothing better verified up to level " .. (x.tope or tope))
    r2 = L("Mejora", "Upgrade")
    t2 = x.vacia and (x.porqueCorto or L("la ranura está vacía", "the slot is empty")) or ((WowF.equipoPorcentaje and WowF.equipoPorcentaje(x) or "") .. (x.porqueCorto and (" · " .. x.porqueCorto) or ""))
  elseif fab then
    r1 = fab.v == "si" and L("Vale la pena", "Worth it") or L("Útil", "Useful")
    c1 = fab.v == "si" and C().verde or C().oro
    local hasta = fab.e.hasta
    t1 = (hasta and hasta > 0 and hasta < 60) and L("te dura hasta el nivel " .. hasta, "lasts until level " .. hasta) or L("nada mejor hasta el nivel " .. tope, "nothing better up to level " .. tope)
    r2 = L("Mejora", "Upgrade")
    t2 = info.pu and L("pieza de tu plan de profesión", "piece from your profession plan") or L("la ranura está vacía", "the slot is empty")
  else
    local hp = pu and pu.porHueco and pu.porHueco[s]
    r1 = L("Puntuación", "Score")
    c1 = C().tenue
    t1 = hp and (math.floor(hp.valor + 0.5) .. " / 100") or SIN_DATOS()
    r2 = L("Para tu nivel", "For your level")
    t2 = (rg and rg.texto) or SIN_DATOS()
  end
  local b1, h1 = dato(k, x0 + 16, y, dw, r1, Y(t1), c1)
  local b2, h2b = dato(k, x0 + 16 + dw + 10, y, dw, r2, Y(t2), (x or fab) and C().verde or C().tenue)
  local hd = math.max(h1, h2b)
  b1:SetHeight(hd); b2:SetHeight(hd)
  y = y + hd + 14
  -- Botones
  local bx = x0 + 16
  if x then
    local esLinea = WowF.equipoLinea and WowF.equipoLinea(x)
    local txt = (x.tipo == "mazmorra") and L("Llévame a la mazmorra ›", "Take me to the dungeon ›") or (esLinea and L("Guíame paso a paso ›", "Guide me step by step ›") or L("Llévame ›", "Take me there ›"))
    local _, w1 = k:boton(bx, y, txt, "estandarte", false, function() if WowF.irARecompensa then WowF.irARecompensa(x) end end)
    bx = bx + w1 + 10
    -- 11-oct: Perseguir (wowF_Caza.lua)
    if WowF.botonPerseguir then bx = bx + WowF.botonPerseguir(k, bx, y, WowF.cazaDesdeMejora and WowF.cazaDesdeMejora(x) or { id = x.id }) + 10 end
    if x.tipo == "mazmorra" then k:boton(bx, y, L("Ver en Mazmorras", "See in Dungeons"), "secundario", false, function() if ctx.irA then ctx.irA("Mazmorras") end end) end
  elseif fab then
    local _, w1 = k:boton(bx, y, L("Cómo fabricarla ›", "How to craft it ›"), "estandarte", false, function() decirFabricar(fab) end)
    bx = bx + w1 + 10
    k:boton(bx, y, L("Ver en Profesiones", "See in Professions"), "secundario", false, function() if ctx.irA then ctx.irA("Profesiones", "objetivo") end end)
  else
    k:boton(bx, y, L("Ver la BiS 30", "See the level 30 BiS"), "secundario", false, function() if ctx.irA then ctx.irA("BiS 30") end end)
  end
  y = y + 34 + 14
  if g and p then -- 12-oct: otras opciones del hueco
    local ok, ny = pcall(OPC.seccion, k, x0, y, w, s, info, nivel, ctx, g, p, dBis)
    if ok and type(ny) == "number" then y = ny end
  end
  card:SetHeight(y - y0)
  k:hasta(y)
  return y
end

local function tarjetaBiS(k, x0, y0, w, s, p, nivel, dBis)
  local card = k:tarjeta(x0, y0, w, 10, "recomendada")
  local y = y0 + 14 + 2
  k:rotulo(x0 + 16, y, L("BiS de nivel 30 en este hueco", "Level 30 BiS in this slot"), C().oro)
  local lista = {}
  if WowF.equipoBiS then local ok, r = pcall(WowF.equipoBiS, s, p, dBis); if ok and type(r) == "table" then lista = r end end
  local bx = lista[1]
  if not bx then
    local _, h = k:texto(x0 + 16, y + 24, SIN_DATOS(), { tam = 13, color = C().tenue, ancho = w - 32 })
    y = y + 24 + h + 14
    card:SetHeight(y - y0); k:hasta(y)
    return y
  end
  local pz = bx.pz
  local chip, color
  if bx.llevas then chip, color = L("La llevas", "You wear it"), "verde"
  elseif bx.tienes and bx.tienes.donde == "bolsas" then chip, color = L("En tus bolsas", "In your bags"), "verde"
  elseif bx.tienes and bx.tienes.donde == "banco" then chip, color = L("En tu banco", "In your bank"), "verde"
  elseif pz.nv and pz.nv > nivel then chip, color = L("Desde nivel ", "From level ") .. pz.nv, "gris"
  elseif not pz.nv then chip, color = L("Nivel por confirmar", "Level to be confirmed"), "gris" -- 11-oct: sin nivel no es "Ya puedes"
  else chip, color = L("Ya puedes", "Available now"), "oro" end
  k:chip(x0 + w - 16, y - 3, chip, color, true)
  y = y + 14 + 10
  icono(k, x0 + 16, y, 44, iconoObj(nil, pz.id), "oro", false)
  local tx = x0 + 16 + 44 + 10
  local _, hn = k:texto(tx, y + 4, (pz.n or "?") .. ((#lista > 1) and (" (" .. bx.hueco .. ")") or ""), { tam = 15, peso = "negrita", ancho = x0 + w - 16 - tx })
  local _, hc = k:texto(tx, y + 4 + hn + 2, Y((WowF.bisComo and WowF.bisComo(pz)) or ""), { tam = 12, color = C().tenue, ancho = x0 + w - 16 - tx })
  y = math.max(y + 44, y + 4 + hn + 2 + hc) + 14
  local yZona = y
  if WowF.botonPerseguir and not bx.llevas then
    WowF.botonPerseguir(k, x0 + 16, y, { id = pz.id, n = pz.n, tipo = "bis", clave = dBis and dBis.clave, hueco = bx.hueco }, true)
    y = y + 28 + 12
  end
  k:zona(x0, y0, w, yZona - y0, bx.accion, function(tt)
    local t = (WowF.bisLineasPieza and WowF.bisLineasPieza(pz, bx.llevas, nivel)) or ""
    if bx.arma then t = t .. "\n" .. bx.arma end
    PUN.pieza(tt, p, pz.id, s, bx.texto .. "\n" .. t .. "\n|cff66ccff" .. L("Clic: te llevo a donde se consigue", "Click: I take you to where you get it") .. "|r", pz.n)
  end)
  card:SetHeight(y - y0)
  k:hasta(y)
  return y
end

local function tarjetaMazmorra(k, x0, y0, w, h, g, nivel, p)
  local card = k:tarjeta(x0, y0, w, math.max(h, 10), nil, MZE, C().borde)
  local y = y0 + 14
  k:rotulo(x0 + 16, y + 1, L("La mejor mazmorra para tu equipo", "Best dungeon for your gear"))
  local mz = g and g.mazmorra
  if not mz then
    local _, hh = k:texto(x0 + 16, y + 24, L("Ninguna mazmorra abierta a tu nivel mejora tu equipo ahora. Vuelve al subir de nivel.", "No dungeon open at your level improves your gear right now. Check again when you level up."),
      { tam = 13, color = C().tenue, ancho = w - 32 })
    y = y + 24 + hh + 14
  else
    local m = mz.m
    if m.d and m.h then k:texto(x0 + w - 16, y, L("niveles ", "levels ") .. m.d .. "-" .. m.h, { tam = 12, color = C().tenue, punto = { "TOPRIGHT", k.marco, "TOPLEFT", x0 + w - 16, -y } }) end
    y = y + 14 + 6
    local _, h3 = k:texto(x0 + 16, y, m.n .. " · " .. mz.n .. (mz.n == 1 and L(" pieza para ti", " piece for you") or L(" piezas para ti", " pieces for you")), { tam = 16, letra = "marca", ancho = w - 32 })
    y = y + h3 + 10
    local cw = math.floor((w - 32 - 16) / 3)
    local alto = 32
    for i, x in ipairs(mz.piezas) do
      if i > 3 then break end
      local px = x0 + 16 + (i - 1) * (cw + 8)
      local n, _, ic = obj(x.id)
      icono(k, px, y, 32, iconoObj(ic, x.id), nil, false)
      local _, hn = k:texto(px + 42, y + 2, n, { tam = 13, peso = "negrita", ancho = cw - 42 })
      alto = math.max(alto, hn + 4)
      k:zona(px, y, cw, 32, function() if WowF.irARecompensa then WowF.irARecompensa(x) end end,
        function(tt) PUN.pieza(tt, p, x.id, x.slot, (WowF.equipoAyuda and WowF.equipoAyuda(x, nivel)) or "", n) end)
    end
    y = y + alto + 12
    k:boton(x0 + 16, y, L("Llévame a la mazmorra", "Take me to the dungeon"), "secundario", true, function() if WowF.irAMazmorra then WowF.irAMazmorra(m) end end)
    y = y + 28 + 14
  end
  if y - y0 > h then card:SetHeight(y - y0) end
  k:hasta(y0 + math.max(h, y - y0))
  return y0 + math.max(h, y - y0)
end

-- 11-oct (Andy: "trae de vuelta lo mejor que podias craftearte segun el nivel"): las fabricadas de tu plan cerca de tu nivel
-- (p.eventos, WowF.valeLaPena). Sin profesion de equipo = la sugerida (p.sugerida). nil = no se dibuja.
local function tarjetaFabricar(k, x0, y0, w, p, nivel, ctx)
  if WowF.mejorasDe and not WowF.mejorasDe("fabricar") then return nil end
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  local lista = {}
  for _, e in ipairs(p.eventos or {}) do
    if e[2] == "equipo" and (e[1] or 0) >= nivel - 3 and (e[1] or 0) <= math.min(nivel + 5, tope) then
      local v = "normal"
      if WowF.valeLaPena then local ok, r = pcall(WowF.valeLaPena, e); v = ok and r or "opcional" end
      if v ~= "opcional" and v ~= "ya" then table.insert(lista, { e = e, v = v }) end
    end
  end
  table.sort(lista, function(a, b)
    if (a.v == "si") ~= (b.v == "si") then return a.v == "si" end
    return (a.e[1] or 0) < (b.e[1] or 0)
  end)
  if #lista == 0 and not p.sugerida then return nil end
  local card = k:tarjeta(x0, y0, w, 10, nil, MZE, C().borde)
  local y = y0 + 14
  k:rotulo(x0 + 16, y, L("Te lo fabricas tú", "You craft it yourself") .. ((p.profesiones and p.profesiones ~= "") and (" · " .. p.profesiones) or ""), C().oro)
  y = y + 14 + 10
  if #lista == 0 then
    local _, h = k:texto(x0 + 16, y, L("Con tus profesiones no fabricas equipo a tu nivel. Si aprendes " .. p.sugerida.nombre .. ", te harías piezas para tu rama.",
      "Your professions craft no gear at your level. If you learn " .. p.sugerida.nombre .. ", you would make pieces for your spec."), { tam = 13, color = C().tenue, ancho = w - 32 })
    y = y + h + 10
    k:boton(x0 + 16, y, L("Ver en Profesiones", "See in Professions"), "secundario", false, function() if ctx.irA then ctx.irA("Profesiones", "objetivo") end end)
    y = y + 34 + 10
  end
  for i, it in ipairs(lista) do
    if i > 3 then break end
    local e = it.e
    local tz = trozos(e[3])
    local nombre = (tz[1] or ""):match("^(.-) %(.-%)$") or tz[1] or "?"
    local prof = (tz[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aún no disponible en WoW Forever; se actualizará)", "(level not yet available in WoW Forever; will be updated)"))
    icono(k, x0 + 16, y, 32, iconoObj(e.ic, e.i), it.v == "si" and "verde" or nil, false)
    local tx = x0 + 16 + 32 + 10
    local _, hn = k:texto(tx, y + 1, nombre, { tam = 13, peso = "negrita", ancho = w - 32 - 42 - 120 })
    local sub = prof .. L(" · pide nivel ", " · requires level ") .. (e[1] or "?")
    local _, hs = k:texto(tx, y + 1 + hn + 2, Y(sub), { tam = 12, color = C().tenue, ancho = w - 32 - 42 - 120 })
    if it.v == "si" then k:chip(x0 + w - 16, y + 2, L("Vale la pena", "Worth it"), "verde", true) end
    local fab = { e = e, nombre = nombre, prof = prof }
    k:zona(x0 + 16, y, w - 32, math.max(32, hn + hs + 4), function() decirFabricar(fab) end,
      function(tt) PUN.pieza(tt, p, e.i, SLOT[e.ra], "|cff999999" .. sub .. "|r\n|cff66ccff" .. L("Clic: receta y materiales en el chat", "Click: recipe and materials in the chat") .. "|r", nombre) end)
    y = y + math.max(32, hn + hs + 4) + 10
  end
  if #lista > 0 and WowF.avisoMejorFabricar then
    local _, ha = k:texto(x0 + 16, y, Y(WowF.avisoMejorFabricar()), { tam = 11, ancho = w - 32 })
    y = y + ha + 6
  end
  y = y + 8
  card:SetHeight(y - y0); k:hasta(y)
  return y
end

-- 11-oct (Andy: "trae de vuelta la prioridad de estadisticas y los avisos"): que buscar en el equipo, a todo lo ancho
local function tarjetaPrioridad(k, x0, y0, w, p)
  local card = k:tarjeta(x0, y0, w, 10, nil, MZE, C().borde)
  local y = y0 + 14
  k:rotulo(x0 + 16, y, L("Qué buscar en tu equipo", "What to look for in your gear"), C().oro)
  y = y + 14 + 10
  local pr = (type(p.prioridad) == "string" and p.prioridad ~= "" and not p.prioridadSinGuia) and (WowF.T and WowF.T(p.prioridad) or p.prioridad) or SIN_DATOS()
  local _, h = k:texto(x0 + 16, y, Y(L("Prioridad de estadísticas: ", "Stat priority: ") .. "|cffffd100" .. pr .. "|r"), { tam = 14, ancho = w - 32 })
  y = y + h + 6
  -- 12-oct (Andy: "que es esto, del personaje o de la guia?"): de donde sale y por que va en ese orden
  local rama = (type(p.ramaPesos) == "string" and p.ramaPesos ~= "") and p.ramaPesos or "?"
  local expl = string.format(L("Orden de estadísticas recomendado para TU rama (%s) según la guía de Icy Veins para WoW Forever (nivel 30). Lo usan la puntuación de equipo y los avisos de mejora. No cambia con tu raza ni con tu equipo. Hit, Crit, Expertise y Haste casi no salen en objetos hasta el nivel 30: por eso aquí van primero las que sí vas a encontrar.",
    "Recommended stat order for YOUR spec (%s) from the Icy Veins WoW Forever guide (level 30). The gear score and upgrade alerts use it. It does not depend on your race or gear. Hit, Crit, Expertise and Haste barely appear on items up to level 30, so the stats you will actually find are listed first."), rama)
  if p.prioridadSinGuia then
    expl = string.format(L("Orden de estadísticas para %s: aún no hay datos de WoW Forever; pendiente de actualizar. La puntuación y los avisos de mejora usan mientras tanto un cálculo propio del addon (marcado como sin guía).",
      "Stat order for %s: no WoW Forever data yet; pending update. Meanwhile the gear score and upgrade alerts use the addon's own estimate (marked as no guide)."), rama)
  end
  if type(p.cambioNivel) == "number" and p.cambioNivel > 0 and type(p.ramaFinal) == "string" and (tonumber(WowF.numero and WowF.numero(UnitLevel("player")) or "") or 0) < p.cambioNivel then
    expl = expl .. " " .. string.format(L("Ahora subes con %s; desde el nivel %d cambiará al orden de %s.", "You level as %s now; from level %d it switches to the %s order."), rama, p.cambioNivel, p.ramaFinal)
  end
  local _, he = k:texto(x0 + 16, y, Y(expl), { tam = 12, ancho = w - 32, color = C().tenue })
  y = y + he + 6
  if not p.prioridadSinGuia and type(p.prioridadGuia) == "string" and p.prioridadGuia ~= "" and p.prioridadGuia ~= p.prioridad then
    local _, hg = k:texto(x0 + 16, y, Y(L("Orden completo de la guía (nivel 30): ", "Full guide order (level 30): ") .. (WowF.T and WowF.T(p.prioridadGuia) or p.prioridadGuia)), { tam = 12, ancho = w - 32, color = C().tenue })
    y = y + hg + 6
  end
  local avisos = {}
  if WowF.avisoPesos then local ok, a = pcall(WowF.avisoPesos, p); if ok then table.insert(avisos, a) end end
  if WowF.avisoMejorEquipo then local ok, a = pcall(WowF.avisoMejorEquipo); if ok then table.insert(avisos, a) end end
  for _, a in ipairs(avisos) do
    if type(a) == "string" and a ~= "" then
      local _, ha = k:texto(x0 + 16, y, Y(a), { tam = 12, ancho = w - 32 })
      y = y + ha + 6
    end
  end
  y = y + 8
  card:SetHeight(y - y0); k:hasta(y)
  return y
end

-- 11-oct: estilo "Comprar": piezas de vendedor de la BiS / pre-BiS de tu faccion (bisDe ya quita la otra faccion).
-- Casa de subastas: sin datos de WoW Forever (aviso).
local function tarjetaComprar(k, x0, y0, w, dBis, nivel)
  local card = k:tarjeta(x0, y0, w, 10, "principal")
  local y = y0 + 14
  k:rotulo(x0 + 16, y, L("Comprar · vendedores de la guía BiS", "Buy · vendors from the BiS guide"), C().oro)
  y = y + 14 + 10
  local lista, vistos = {}, {}
  for _, f in ipairs((dBis and dBis.huecos) or {}) do
    local todas = { f.bis }
    for _, pz in ipairs(f.prebis or {}) do table.insert(todas, pz) end
    for _, pz in ipairs(todas) do
      if type(pz) == "table" and pz.t == "vendedor" and not vistos[pz.id] then vistos[pz.id] = true; table.insert(lista, { pz = pz, hueco = f.hueco }) end
    end
  end
  table.sort(lista, function(a, b) return (a.pz.nv or 0) < (b.pz.nv or 0) end)
  if #lista == 0 then
    local _, h = k:texto(x0 + 16, y, L("Tu guía BiS no trae piezas de vendedor para tu facción: ", "Your BiS guide has no vendor pieces for your faction: ") .. SIN_DATOS(), { tam = 13, color = C().tenue, ancho = w - 32 })
    y = y + h + 10
  end
  for i, e in ipairs(lista) do
    if i > 5 then break end
    local pz = e.pz
    icono(k, x0 + 16, y, 32, iconoObj(nil, pz.id), (pz.nv or 0) <= nivel and "verde" or nil, false)
    local tx = x0 + 16 + 32 + 10
    local _, hn = k:texto(tx, y + 1, (pz.n or "?") .. " · " .. e.hueco, { tam = 13, peso = "negrita", ancho = w - 32 - 42 - 110 })
    local sub = ((pz.nv or 0) > nivel) and (L("desde nivel ", "from level ") .. pz.nv) or L("ya puedes", "available now")
    if pz.ok == false then sub = sub .. " · " .. L("sin confirmar: se actualizará", "not confirmed: it will be updated") end
    k:texto(tx, y + 1 + hn + 2, sub, { tam = 12, color = C().tenue, ancho = w - 32 - 42 - 110 })
    local pzC = pz
    k:zona(x0 + 16, y, w - 32 - 110, 32, function() if WowF.irABiS then WowF.irABiS(pzC) end end,
      function(tt) PUN.pieza(tt, p, pz.id, nil, ((WowF.bisComo and WowF.bisComo(pz)) or "") .. "\n|cff66ccff" .. L("Clic: te llevo al vendedor", "Click: I take you to the vendor") .. "|r", pz.n) end)
    if WowF.botonPerseguir then WowF.botonPerseguir(k, x0 + w - 16, y + 2, { id = pz.id, n = pz.n, tipo = "bis", clave = dBis and dBis.clave, hueco = e.hueco }, true, true) end
    y = y + math.max(32, hn + 18) + 10
  end
  local _, ha = k:texto(x0 + 16, y, L("Casa de subastas: ", "Auction house: ") .. SIN_DATOS(), { tam = 12, color = C().oro, ancho = w - 32 })
  y = y + ha + 14
  card:SetHeight(y - y0); k:hasta(y)
  return y
end

function WowF.vistaEquipo(p, hoja, ancho, ctx)
  if not (WowF.estilo and WowF.estilo.tarjeta and WowF.vistaKit and WowF.equipoGuia) then return nil end
  if type(p) ~= "table" then return nil end
  ctx = ctx or {}
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
  local nivel = nivelPj()
  local okG, g = pcall(WowF.equipoGuia, p)
  if not okG or type(g) ~= "table" then g = { ranuras = {} } end
  local pu
  if WowF.puntuacionEquipo then local ok, r = pcall(WowF.puntuacionEquipo, p); if ok then pu = r end end
  local est, cuenta = estados(p, g, nivel)
  -- Hueco elegido: el que pulsaste; si no, el primero con mejora en el orden de la figura; si no, el que mas sube
  if not sel or not est[sel] then
    sel = nil
    for _, lista in ipairs({ IZQ, DER, ARMAS }) do
      for _, s in ipairs(lista) do if not sel and (est[s].est == "mejora" or est[s].est == "peq") then sel = s end end
    end
    sel = sel or (pu and pu.peor) or 1
  end
  -- Derecha
  local fx, fw = MUNECO_W + GAP, ancho - MUNECO_W - GAP
  local dBis
  if WowF.bisDe then local ok, d = pcall(WowF.bisDe, p); if ok then dBis = d end end
  ctx.anchoFiltro = fw
  local y = filtro(k, fx, ctx) + GAP
  if WowF.barraVerComo then y = WowF.barraVerComo(k, fx, y, fw, ctx) end
  local nivelVer = (WowF.verComoNivel and WowF.verComoNivel()) or nivel
  if WowF.estiloEquipo and WowF.estiloEquipo() == "comprar" then
    y = tarjetaComprar(k, fx, y, fw, dBis, nivelVer) + GAP
  elseif not (WowF.verComoActivo and WowF.verComoActivo()) then
    y = tarjetaMejora(k, fx, y, fw, sel, est[sel], nivel, ctx, pu, g, p, dBis) + GAP
  end
  y = tarjetaBiS(k, fx, y, fw, sel, p, nivelVer, dBis) + GAP
  if not (WowF.estiloEquipo and WowF.estiloEquipo() == "comprar") then
    local yf = tarjetaFabricar(k, fx, y, fw, p, nivel, ctx)
    if yf then y = yf + GAP end
  end
  local resto = math.max(ALTO_BASE - y, 0)
  local fin = tarjetaMazmorra(k, fx, y, fw, resto, g, nivel, p)
  -- Izquierda (alto = el de la columna derecha si es mayor)
  local card = muneco(k, p, g, est, cuenta, nivel, ctx, pu)
  local alto = math.max(ALTO_BASE, fin)
  card:SetHeight(alto)
  k:hasta(alto)
  tarjetaPrioridad(k, 0, alto + GAP, ancho, p)
  m:SetHeight(math.max(1, k.alto))
  return m, k.alto, k.textos
end
