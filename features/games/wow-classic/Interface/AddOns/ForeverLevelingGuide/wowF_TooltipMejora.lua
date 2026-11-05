-- Forever Leveling Guide: mejora en el tooltip de los objetos (5-oct-2026, como Pawn, pero con los pesos de SUBIR de nivel de tu rama).
-- En el tooltip de cualquier objeto equipable (bolsa, vendedor, subasta, enlace del chat, recompensas) anade UNA linea:
--   verde   "Mejora para tu rama <rama>: +X % (ranura)"          (comparacion segura con lo que llevas: WowF.evaluarMejora)
--   verde   "Te servirá al nivel N: +X % para tu rama <rama>"    (mejora, pero aun no tienes el nivel)
--   dorado  "Mejora pequeña, depende: +X % para tu rama <rama>"  (7-oct: pierdes algo que cuenta y casi se compensa)
--           y debajo de la verde o la dorada, el porque corto: "+6 Agility, +2 Armor; pierdes 3 Stamina (vale menos para <rama>)"
--   gris    "No mejora lo que llevas"  /  "No se pudo comparar con lo que llevas"
--   naranja "Tu clase no puede llevarlo"
-- Nada si no es equipo, si es lo que llevas puesto o si aun no hay plan/rama. /wowf tooltip on|off (tambien en Ajustes).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, GRIS = "|cff1eff00", "|cff9d9d9d"

local function db()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  return WowFExportarDB
end
function WowF.tooltipMejoraActivo() return db().tooltipMejora ~= false end

-- Resultados por enlace (y por idioma): el tooltip se redibuja muchas veces. Se olvida al cambiar lo puesto, el nivel o los talentos.
-- 5-oct (revision): la clave lleva tambien la rama, la rama de los pesos y el objetivo del plan (cambiar de rama con
-- /wowf rama o en el Libro no lanza ningun evento del juego). "No se pudo comparar" se guarda solo unos 5 segundos.
local cache, enCache = {}, 0
local function olvidar() cache, enCache = {}, 0 end
local INCIERTO_VIDA = 5
local function ahora() if type(GetTime) == "function" then local ok, t = pcall(GetTime); if ok and type(t) == "number" then return t end end return nil end
local function planActual()
  if not WowF.armarPlan then return nil, "" end
  local ok, p = pcall(WowF.armarPlan)
  if not ok or type(p) ~= "table" then return nil, "" end
  return p, tostring(p.ramaNombre or "") .. "/" .. tostring(p.ramaPesos or "") .. "/" .. tostring(p.indiceRama or "") .. "/" .. tostring(p.objetivo or "")
end
WowF._tooltipMejoraOlvidar = olvidar -- para las pruebas

local SIM = {}
local function num(v) v = tonumber(v); return v and math.floor(v + 0.5) or nil end
local function dif(d) return (d > 0) and ("+" .. d) or tostring(d) end
local function col(d) return (d > 0) and "|cff33ff66" or ((d < 0) and "|cffff4d4d" or "|cff999999") end
function SIM.lineas(plan, link)
  if not (WowF.simularPieza and type(plan) == "table") then return nil end
  local id = tonumber(link:match("item:(%d+)"))
  if not id then return nil end
  local ok, s = pcall(WowF.simularPieza, plan, id, nil)
  if not ok or type(s) ~= "table" then return nil end
  local a, d = num(s.antes), num(s.despues)
  if not a or not d then return nil end
  local l = { PREFIJO .. col(d - a) .. L("tu puntuación ", "your score ") .. a .. " » " .. d .. " (" .. dif(d - a) .. ")|r" }
  local n = 0
  for _, st in ipairs(type(s.stats) == "table" and s.stats or {}) do
    if n >= 3 then break end
    local nom = type(st) == "table" and (st.nombre or st[1]) or nil
    local sa, sd = type(st) == "table" and num(st.antes) or nil, type(st) == "table" and num(st.despues) or nil
    if type(nom) == "string" and sa and sd and sa ~= sd then
      n = n + 1
      l[#l + 1] = "   " .. col(sd - sa) .. nom .. " " .. sa .. " » " .. sd .. " (" .. dif(sd - sa) .. ")|r"
    end
  end
  return l
end

local function pct(e)
  if e.vacia then return L("ranura vacía", "empty slot") end
  if not e.cuanto then return nil end
  local x = math.floor(e.cuanto * 100 + 0.5)
  return (x >= 1) and WowF.textoMejora(e.cuanto * 100) or "+<1 %"
end

-- La linea para un enlace: texto, r, g, b (nil = nada)
function WowF.lineaMejora(link)
  if type(link) ~= "string" or link == "" or (issecretvalue and issecretvalue(link)) then return nil end
  local ing = WowF.enIngles and WowF.enIngles() or false
  local plan, firma = planActual()
  local clave = link .. (ing and "|en" or "|es") .. "|" .. firma
  local c = cache[clave]
  if c and c.hasta then
    local t = ahora()
    if not t or t > c.hasta then cache[clave] = nil; c = nil end
  end
  if c then return c[1], c[2], c[3], c[4], c[5], c[6] end
  if not WowF.evaluarMejora then return nil end
  local ok, e = pcall(WowF.evaluarMejora, link, plan)
  if not ok or type(e) ~= "table" then return nil end -- no es equipo o el cliente aun no tiene el objeto
  local t, r, g, b
  local porque = (e.estado == "mejora" or e.estado == "dudosa" or e.estado == "nomejora") and type(e.porque) == "string" and e.porque ~= "" and e.porque or nil
  local rama = e.rama or ""
  local ranura = e.ranura and (" (" .. e.ranura .. ")") or ""
  local futuro = (e.desde or 0) > (e.nivel or 0)
  -- 7-oct: lo que pide mas nivel que el tope de la beta no es una mejora que puedas tener (un Rogue de 30 veia "Upgrade at level 41")
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  if (e.estado == "mejora" or e.estado == "dudosa") and (e.desde or 0) > tope then
    t, r, g, b = L("Pide nivel " .. e.desde .. ": la beta llega al " .. tope .. ", hoy no te sirve", "Requires level " .. e.desde .. ": the beta goes up to " .. tope .. ", not usable yet"), 0.62, 0.62, 0.62
    porque = nil
  elseif e.estado == "noclase" then
    -- 12-oct (auditoria): con motivo ("tu clase aprende Mail al nivel 40 y la beta llega al 30...") se dice el motivo
    if type(e.porque) == "string" and e.porque ~= "" then
      t, r, g, b = (e.porque:gsub("^%l", string.upper)), 1, 0.5, 0.25
    else
      t, r, g, b = L("Tu clase no puede llevarlo", "Your class cannot use it"), 1, 0.5, 0.25
    end
  elseif e.estado == "mejora" then
    local x = pct(e)
    if futuro then
      t = x and L("Te servirá al nivel " .. e.desde .. ": " .. x .. " para tu rama " .. rama .. ranura,
        "Upgrade at level " .. e.desde .. ": " .. x .. " for your " .. rama .. " spec" .. ranura)
        or L("Te servirá al nivel " .. e.desde .. " (rama " .. rama .. ")" .. ranura, "Upgrade at level " .. e.desde .. " (" .. rama .. " spec)" .. ranura)
      r, g, b = 0.6, 1, 0.3
    else
      t = x and L("Mejora para tu rama " .. rama .. ": " .. x .. ranura, "Upgrade for your " .. rama .. " spec: " .. x .. ranura)
        or L("Mejora para tu rama " .. rama .. ranura, "Upgrade for your " .. rama .. " spec" .. ranura)
      r, g, b = 0.12, 1, 0
    end
  elseif e.estado == "dudosa" then
    local x = pct(e)
    if futuro then
      t = L("Mejora pequeña al nivel " .. e.desde .. ", depende" .. (x and (": " .. x) or "") .. " (rama " .. rama .. ")" .. ranura,
        "Small upgrade at level " .. e.desde .. ", it depends" .. (x and (": " .. x) or "") .. " (" .. rama .. " spec)" .. ranura)
    else
      t = L("Mejora pequeña, depende" .. (x and (": " .. x) or "") .. " (rama " .. rama .. ")" .. ranura,
        "Small upgrade, it depends" .. (x and (": " .. x) or "") .. " (" .. rama .. " spec)" .. ranura)
    end
    r, g, b = 1, 0.82, 0
  elseif e.estado == "nomejora" then
    t = futuro and L("No mejora lo que llevas (pide nivel " .. e.desde .. ")", "Not an upgrade over what you wear (requires level " .. e.desde .. ")")
      or L("No mejora lo que llevas", "Not an upgrade over what you wear")
    r, g, b = 0.62, 0.62, 0.62
  elseif e.estado == "incierto" then
    -- Cache corta (INCIERTO_VIDA): puede ser que los datos aun no esten; pasado ese rato se vuelve a intentar
    t, r, g, b = L("No se pudo comparar con lo que llevas", "Could not compare with what you wear"), 0.62, 0.62, 0.62
    local hora = ahora()
    if hora then
      if enCache > 400 then olvidar() end
      cache[clave] = { t, r, g, b, hasta = hora + INCIERTO_VIDA }; enCache = enCache + 1
    end
    return t, r, g, b
  else
    return nil -- "puesto" (lo llevas) o "sinplan"
  end
  -- 13-oct (Andy: "poder simular cuanto sube"): con WowF.simularPieza (wowF_EquipoGuia.lua), tu puntuacion antes y despues
  -- y como mucho 3 estadisticas. Solo si es para tu clase y la puedes usar en la beta; sin datos = nada.
  local sim
  if (e.estado == "mejora" or e.estado == "dudosa" or e.estado == "nomejora") and (e.desde or 0) <= tope then sim = SIM.lineas(plan, link) end
  -- 16-oct (Andy: "que cantidad de porcentaje representa cada stat"): de donde sale la mejora, estadistica por estadistica
  if (e.estado == "mejora" or e.estado == "dudosa") and (e.desde or 0) <= tope and WowF.desgloseMejora then
    local okD, dg = pcall(WowF.desgloseMejora, e)
    if okD and dg then sim = type(sim) == "table" and sim or {}; table.insert(sim, 1, "|cffe6d98c" .. dg .. "|r") end
  end
  if enCache > 400 then olvidar() end
  cache[clave] = { t, r, g, b, porque, sim }; enCache = enCache + 1
  return t, r, g, b, porque, sim
end

-- ===================== Engancharse a los tooltips =====================
local function nombreDe(tt) if type(tt) == "table" and tt.GetName then local ok, n = pcall(tt.GetName, tt); if ok and type(n) == "string" then return n end end return "" end
local ocupado = false
local function anadir(tt, data, mostrar)
  if ocupado or not WowF.tooltipMejoraActivo() or type(tt) ~= "table" or not tt.AddLine then return end
  if nombreDe(tt):find("Shopping", 1, true) then return end -- la comparacion de lo que llevas (ShoppingTooltip1/2): no
  local link
  if tt.GetItem then
    local ok, _, l = pcall(tt.GetItem, tt)
    if ok and type(l) == "string" and not (issecretvalue and issecretvalue(l)) then link = l end
  end
  if not link and type(data) == "table" then
    if type(data.hyperlink) == "string" and not (issecretvalue and issecretvalue(data.hyperlink)) then link = data.hyperlink
    elseif type(data.id) == "number" and not (issecretvalue and issecretvalue(data.id)) then link = "item:" .. data.id end
  end
  if not link or tt.wowfMejoraHecha == link then return end
  ocupado = true
  local ok, t, r, g, b, porque, sim = pcall(WowF.lineaMejora, link)
  ocupado = false
  if not ok or not t then return end
  tt.wowfMejoraHecha = link
  pcall(tt.AddLine, tt, t, r, g, b, true)
  -- 7-oct: el porque corto debajo (lo que ganas y lo que pierdes), en blanco suave
  if porque then pcall(tt.AddLine, tt, porque, 0.9, 0.9, 0.9, true) end
  -- 13-oct: tu puntuacion si te la pones (y hasta 3 estadisticas)
  if type(sim) == "table" then for _, s in ipairs(sim) do pcall(tt.AddLine, tt, s, 1, 1, 1, true) end end
  if mostrar and tt.Show then pcall(tt.Show, tt) end -- el gancho clasico necesita Show para ajustar el tamano
end
WowF._tooltipMejoraAnadir = anadir -- para las pruebas

-- ===================== Tooltip completo de una pieza que recomienda el addon =====================
-- 16-oct (Andy: "en los BiS, pre-BiS, Equipo... no te dice los stats, ni por que es tu BiS, ni en que te mejora"):
-- WowF.tooltipPieza(tt, id, opts) pone el tooltip REAL del objeto (estadisticas del cliente, datos de Forever) y debajo:
--   la linea de mejora + el porque + la puntuacion (gancho de arriba), "De donde sale la mejora" (cuanto aporta cada estadistica,
--   en % de la mejora total, con los pesos de tu rama), opts.porque (p. ej. por que es tu BiS) y opts.texto (de donde sale, clic).
-- Si el cliente no da el objeto (sin datos o sin la funcion), el mismo contenido como texto. Todo en una tabla: tope de locales.
local TP = {}
function TP.num(v)
  if math.abs(v - math.floor(v + 0.5)) < 0.05 then return tostring(math.floor(v + 0.5)) end
  return string.format("%.1f", v)
end
-- "De donde sale la mejora: +12 Intellect = 60 %, +8 Spell Power = 30 %, otras 10 %" (nil si no hay mejora que repartir)
function WowF.desgloseMejora(e)
  local det = type(e) == "table" and e.det or nil
  local G = type(det) == "table" and tonumber(det.G) or nil
  if not G or G <= 0 or type(det.ganas) ~= "table" then return nil end
  local partes, suma = {}, 0
  for _, x in ipairs(det.ganas) do
    local p = math.floor((tonumber(x.efecto) or 0) / G * 100 + 0.5)
    if p >= 1 and type(x.n) == "string" then
      partes[#partes + 1] = "+" .. TP.num(math.abs(tonumber(x.d) or 0)) .. " " .. x.n .. " = " .. p .. " %"
      suma = suma + p
    end
  end
  if #partes == 0 then return nil end
  if suma <= 97 then partes[#partes + 1] = L("otras ", "others ") .. (100 - suma) .. " %" end
  return L("De dónde sale la mejora: ", "Where the upgrade comes from: ") .. table.concat(partes, ", ")
end
-- Lineas que van debajo del tooltip del objeto: { texto, r, g, b }
function TP.extras(id, opts, conMejora)
  local l = {}
  local link = "item:" .. id
  if GetItemInfo then local ok, _, lk = pcall(GetItemInfo, id); if ok and type(lk) == "string" and not (issecretvalue and issecretvalue(lk)) then link = lk end end
  if conMejora then -- el gancho esta apagado (Ajustes) o no hay tooltip del cliente: la mejora va aqui
    local ok, t, r, g, b, porque, sim = pcall(WowF.lineaMejora, link)
    if ok and t then
      l[#l + 1] = { t, r, g, b }
      if porque then l[#l + 1] = { porque, 0.9, 0.9, 0.9 } end
      for _, s in ipairs(type(sim) == "table" and sim or {}) do l[#l + 1] = { s, 1, 1, 1 } end
    end
  end
  if type(opts.porque) == "string" and opts.porque ~= "" then
    l[#l + 1] = { " ", 1, 1, 1 }
    l[#l + 1] = { opts.porque, 1, 0.82, 0 }
  end
  if type(opts.texto) == "string" and opts.texto ~= "" then
    l[#l + 1] = { " ", 1, 1, 1 }
    for s in (opts.texto .. "\n"):gmatch("(.-)\n") do if s ~= "" then l[#l + 1] = { s, 1, 1, 1 } end end
  end
  return l
end
function TP.poner(tt, l) for _, x in ipairs(l) do pcall(tt.AddLine, tt, x[1], x[2], x[3], x[4], true) end end
-- Al redibujarse (el cliente trae los datos del objeto un poco despues) el tooltip se rehace: las lineas se vuelven a poner
function TP.alProcesar(tt, data)
  local x = type(tt) == "table" and rawget(tt, "wowfExtra") or nil
  if type(x) ~= "table" or tt.wowfExtraHecha == x.id then return end
  local id = type(data) == "table" and tonumber(data.id) or nil
  if not id and tt.GetItem then
    local ok, _, lk = pcall(tt.GetItem, tt)
    if ok and type(lk) == "string" and not (issecretvalue and issecretvalue(lk)) then id = tonumber(lk:match("item:(%d+)")) end
  end
  if id ~= x.id then return end
  tt.wowfExtraHecha = x.id
  TP.poner(tt, TP.extras(x.id, x.opts, not WowF.tooltipMejoraActivo()))
end
-- opts = { nombre, porque, texto }. Devuelve true si salio el tooltip real del objeto.
function WowF.tooltipPieza(tt, id, opts)
  opts = opts or {}
  id = tonumber(id)
  if type(tt) ~= "table" then return false end
  local real = false
  if id and type(tt.SetItemByID) == "function" then
    tt.wowfExtra, tt.wowfExtraHecha = { id = id, opts = opts }, nil
    local ok = pcall(tt.SetItemByID, tt, id)
    if ok and tt.GetItem then
      local ok2, _, lk = pcall(tt.GetItem, tt)
      real = ok2 and type(lk) == "string" and not (issecretvalue and issecretvalue(lk)) and tonumber(lk:match("item:(%d+)")) == id or false
    end
    if real then
      if tt.wowfExtraHecha ~= id then tt.wowfExtraHecha = id; TP.poner(tt, TP.extras(id, opts, not WowF.tooltipMejoraActivo() or tt.wowfMejoraHecha == nil)) end
      return true
    end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  -- Sin tooltip del cliente: todo como texto (la proxima vez el objeto ya estara cargado)
  tt.wowfExtra = nil
  local t = { tostring(opts.nombre or "?") }
  if id then
    for _, x in ipairs(TP.extras(id, { porque = opts.porque }, true)) do t[#t + 1] = x[1] end
    if not (GetItemInfo and select(2, pcall(GetItemInfo, id))) then
      t[#t + 1] = "|cff999999" .. L("Estadísticas: pasa el ratón otra vez en un momento (el juego aún no cargó el objeto).", "Stats: hover again in a moment (the game has not loaded the item yet).") .. "|r"
    end
  end
  if type(opts.texto) == "string" and opts.texto ~= "" then t[#t + 1] = " "; t[#t + 1] = opts.texto end
  pcall(tt.SetText, tt, table.concat(t, "\n"), 1, 1, 1, 1, true)
  return false
end
WowF._tooltipPiezaExtras, WowF._tooltipPiezaAlProcesar = TP.extras, TP.alProcesar -- para las pruebas

local conProcesador = false
if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
  and type(Enum) == "table" and type(Enum.TooltipDataType) == "table" and Enum.TooltipDataType.Item ~= nil then
  conProcesador = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tt, data)
    if tt then tt.wowfMejoraHecha = nil; tt.wowfExtraHecha = nil end -- cada proceso es un tooltip nuevo
    anadir(tt, data, false)
    pcall(TP.alProcesar, tt, data)
  end)
end
if not conProcesador then
  for _, nombre in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local tt = _G[nombre]
    if type(tt) == "table" and tt.HookScript then
      pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) anadir(self, nil, true); pcall(TP.alProcesar, self, nil) end)
      pcall(tt.HookScript, tt, "OnTooltipCleared", function(self) self.wowfMejoraHecha = nil; self.wowfExtraHecha = nil end)
    end
  end
end
-- Al ocultarse, las lineas extra se olvidan (el mismo objeto en tus bolsas no las lleva)
if type(GameTooltip) == "table" and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function(self) self.wowfExtra = nil; self.wowfExtraHecha = nil end)
end
WowF._tooltipMejoraModo = function() return conProcesador and "procesador" or "clasico" end -- para las pruebas

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED", "SKILL_LINES_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() olvidar() end)

-- ===================== /wowf tooltip =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "tooltip" then
    local t = db()
    if resto == "off" or resto == "no" then t.tooltipMejora = false elseif resto == "on" or resto == "si" then t.tooltipMejora = true
    else t.tooltipMejora = not WowF.tooltipMejoraActivo() end
    print(PREFIJO .. L("mejora en el tooltip ", "upgrade line in tooltips ") .. (WowF.tooltipMejoraActivo() and (VERDE .. L("ENCENDIDA", "ON")) or (GRIS .. L("APAGADA", "OFF"))) .. "|r" ..
      L(". /wowf tooltip on|off", ". /wowf tooltip on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end

if WowF.registrarCasillaOpciones then
  WowF.registrarCasillaOpciones("tooltipMejora", function() return L("Mostrar si un objeto me mejora (tooltip)", "Show if an item is an upgrade (tooltip)") end)
end
