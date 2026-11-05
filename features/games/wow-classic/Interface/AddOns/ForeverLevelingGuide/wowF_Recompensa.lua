-- Forever Leveling Guide: elegir la recompensa de mision (5-oct-2026, como el "Quest Reward Advisor" de Zygor).
-- En la ventana de la mision (al entregarla: QUEST_COMPLETE; al leerla: QUEST_DETAIL, "lo que te daran") recorre las recompensas
-- a elegir y RESALTA, sin elegir nunca por ti:
--   VERDE  "Mejora para ti (+X %)": la que mas mejora lo que llevas segun los pesos de tu rama (WowF.evaluarMejora de
--          wowF_Comparar.lua, la misma comparacion del panel y del aviso de botin). Solo si tu clase la puede llevar y la
--          comparacion es segura (si algo no se pudo leer, no se afirma).
--   DORADO "Vale mas al vendedor: Xg Ys": si ninguna mejora y hay mas de una, la de mayor precio REAL (precio de venta del
--          juego, o precio de subasta real de Auctionator / TSM / lo que viste, si se puede subastar). Nunca un precio inventado.
-- Al entregar la mision tambien lo dice en el chat (por si el marco de la recompensa no se encuentra).
-- /wowf recompensa on|off (tambien en Ajustes). Encendido por defecto.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, ORO, GRIS = "|cff1eff00", "|cffffd100", "|cff9d9d9d"

local function numero(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  local ok, n = pcall(function() return tonumber(v) end)
  if ok then return n end
  return nil
end
local function llamar(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, v = pcall(f, ...)
  if ok and not (issecretvalue and issecretvalue(v)) then return v end
  return nil
end
local function texto(v) if type(v) == "string" and not (issecretvalue and issecretvalue(v)) then return v end return nil end
local function db()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  return WowFExportarDB
end
function WowF.recompensaActiva() return db().recompensa ~= false end

local function dinero(c)
  if WowF.avisoBotinDinero then return WowF.avisoBotinDinero(c) end
  c = math.floor(c or 0)
  local g, s, co = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "g" end
  if s > 0 then t[#t + 1] = s .. "s" end
  if co > 0 or #t == 0 then t[#t + 1] = co .. "c" end
  return table.concat(t, " ")
end

-- Precio real de una recompensa: subasta real (si no se liga al recogerla) o el del vendedor. cobre, "subasta"/"vendedor", fuente
local function precio(link)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, link) }
  if not r[1] or r[2] == nil then return nil end
  local sell, bind = numero(r[12]) or 0, numero(r[15])
  if bind ~= 1 and WowF.precioSubasta then
    local id = tonumber(link:match("item:(%d+)") or "")
    local ok, p, fuente = pcall(WowF.precioSubasta, link, id)
    p = ok and numero(p) or nil
    if p and p > sell then return p, "subasta", (fuente == "visto") and L("lo viste", "you saw it") or fuente end
  end
  return sell, "vendedor"
end

-- La decision (sin tocar la ventana). Devuelve nil (nada que resaltar) o { indice, tipo = "mejora"|"vende", texto, link },
-- y "pendiente" como 2.o valor si el cliente aun no tenia algun objeto (se reintenta).
function WowF.recompensaDecidir()
  local n = numero(llamar(GetNumQuestChoices)) or 0
  if n < 1 then return nil end
  local plan
  if WowF.armarPlan then local ok, p = pcall(WowF.armarPlan); plan = ok and p or nil end
  if type(plan) ~= "table" then plan = false end -- false = sin plan (evaluarMejora no lo vuelve a armar)
  local pendiente = false
  local mejor, mejorValor, caro, caroPrecio, caroDonde, caroFuente
  local dudosa, dudosaValor -- 7-oct: mejora pequena (pierdes algo que cuenta): solo si ninguna es mejora clara
  for i = 1, n do
    local link = texto(llamar(GetQuestItemLink, "choice", i))
    if not link then
      pendiente = true
    else
      -- 12-oct (auditoria de mejoras): con pcall; si un objeto da error, cuenta solo por su precio (antes se caia la eleccion entera)
      local e, fallo = nil, false
      if WowF.evaluarMejora then
        local okE, r = pcall(WowF.evaluarMejora, link, plan)
        if okE and type(r) == "table" then e = r elseif not okE then fallo = true end
      end
      if e == nil then
        -- no es equipo (pocion, comida...) o aun sin datos: cuenta solo por el precio (si fallo al compararlo, no se espera nada)
        local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if not fallo and type(f) == "function" and llamar(f, link) == nil then pendiente = true end
      elseif (e.estado == "mejora" or e.estado == "dudosa") and (e.desde or 0) > ((WowFDatos and WowFDatos.topeBeta) or 30) then
        -- 7-oct: pide mas nivel que el tope de la beta: no es una mejora que puedas tener
      elseif e.estado == "mejora" then
        local v = e.cuanto or math.huge -- ranura vacia (o lo puesto no suma nada): la mayor mejora
        -- 12-oct (auditoria): una mejora que te sirve YA gana a una que pide mas nivel que el tuyo
        local ya = (e.desde or 0) <= (e.nivel or 0)
        if not mejor or (ya and not mejor.ya) or (ya == mejor.ya and v > mejorValor) then mejor, mejorValor = { indice = i, link = link, e = e, ya = ya }, v end
      elseif e.estado == "dudosa" then
        local v = e.cuanto or 0
        if not dudosa or v > dudosaValor then dudosa, dudosaValor = { indice = i, link = link, e = e }, v end
      end
      local p, donde, fuente = precio(link)
      if p and p > 0 and (not caro or p > caroPrecio) then caro, caroPrecio, caroDonde, caroFuente = { indice = i, link = link }, p, donde, fuente end
    end
  end
  if mejor then
    local e = mejor.e
    local cuanto
    if e.vacia then cuanto = L("ranura vacía", "empty slot")
    elseif e.cuanto then
      local x = math.floor(e.cuanto * 100 + 0.5)
      cuanto = (x >= 1) and WowF.textoMejora(e.cuanto * 100) or "+<1 %"
    end
    local t
    if (e.desde or 0) > (e.nivel or 0) then
      t = cuanto and L("Mejora para ti al nivel " .. e.desde .. " (" .. cuanto .. ")", "Upgrade for you at level " .. e.desde .. " (" .. cuanto .. ")")
        or L("Mejora para ti al nivel " .. e.desde, "Upgrade for you at level " .. e.desde)
    else
      t = cuanto and L("Mejora para ti (" .. cuanto .. ")", "Upgrade for you (" .. cuanto .. ")") or L("Mejora para ti", "Upgrade for you")
    end
    return { indice = mejor.indice, tipo = "mejora", texto = t, link = mejor.link, porque = e.porque }, pendiente and "pendiente" or nil
  end
  if dudosa then
    local e = dudosa.e
    local x = e.cuanto and math.floor(e.cuanto * 100 + 0.5) or nil
    local cuanto = x and ((x >= 1) and WowF.textoMejora(e.cuanto * 100) or "+<1 %") or nil
    local t = cuanto and L("Mejora pequeña (" .. cuanto .. "), depende", "Small upgrade (" .. cuanto .. "), it depends")
      or L("Mejora pequeña, depende", "Small upgrade, it depends")
    return { indice = dudosa.indice, tipo = "dudosa", texto = t, link = dudosa.link, porque = e.porque }, pendiente and "pendiente" or nil
  end
  if caro and n >= 2 then
    local t
    if caroDonde == "subasta" then
      t = L("Vale más en subasta: " .. dinero(caroPrecio), "Best auction price: " .. dinero(caroPrecio)) .. (caroFuente and (" (" .. caroFuente .. ")") or "")
    else
      t = L("Vale más al vendedor: " .. dinero(caroPrecio), "Best vendor price: " .. dinero(caroPrecio))
    end
    return { indice = caro.indice, tipo = "vende", texto = t, link = caro.link }, pendiente and "pendiente" or nil
  end
  return nil, pendiente and "pendiente" or nil
end

-- ===================== Resaltar en la ventana =====================
-- El boton de la recompensa i: moderno (QuestInfoRewardsFrame.RewardButtons, type = "choice") o clasico (QuestInfoItemN)
local function visible(b) return type(b) == "table" and (not b.IsShown or b:IsShown()) end
local function botonDe(i)
  local cont = _G.QuestInfoRewardsFrame
  if type(cont) == "table" and type(cont.RewardButtons) == "table" then
    for _, b in pairs(cont.RewardButtons) do
      if visible(b) and b.type == "choice" and b.GetID then
        local ok, id = pcall(b.GetID, b)
        if ok and id == i then return b end
      end
    end
  end
  for _, nombre in ipairs({ "QuestInfoRewardsFrameQuestInfoItem" .. i, "QuestInfoItem" .. i }) do
    local b = _G[nombre]
    if visible(b) and (b.type == nil or b.type == "choice") then return b end
  end
  return nil
end

local marcas = {} -- botones marcados ahora
local function quitarMarcas()
  for _, b in pairs(marcas) do if type(b.wowfMarca) == "table" then b.wowfMarca:Hide() end end
  marcas = {}
end
local function marcar(b, tipo, t)
  local m = type(b.wowfMarca) == "table" and b.wowfMarca or nil
  if not m then
    m = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
    m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
    if m.SetFrameLevel and b.GetFrameLevel then pcall(function() m:SetFrameLevel(b:GetFrameLevel() + 5) end) end
    -- 11-oct (hibrido): borde fino liso (sin el Tooltip-Border de Blizzard) y etiqueta Signika sobre piedra oscura
    if m.SetBackdrop then m:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 }) end
    m.fondo = m:CreateTexture(nil, "ARTWORK")
    m.etiqueta = WowF.estilo.etiqueta(m, nil, WowF.estilo.color.texto, 9)
    m.etiqueta:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -5, 4)
    m.fondo:SetPoint("TOPLEFT", m.etiqueta, "TOPLEFT", -3, 2)
    m.fondo:SetPoint("BOTTOMRIGHT", m.etiqueta, "BOTTOMRIGHT", 3, -2)
    local o = WowF.estilo.color.oscuro or { 0, 0, 0 }
    if m.fondo.SetColorTexture then m.fondo:SetColorTexture(o[1], o[2], o[3], 0.88) end
    if m.EnableMouse then m:EnableMouse(false) end -- que el clic llegue al boton de la recompensa
    b.wowfMarca = m
  end
  local r, g, bl = 0.12, 1, 0
  if tipo ~= "mejora" then r, g, bl = 1, 0.82, 0 end
  if m.SetBackdropBorderColor then m:SetBackdropBorderColor(r, g, bl, 0.9) end
  m.etiqueta:SetText((tipo == "mejora" and VERDE or ORO) .. t .. "|r")
  m:Show()
  marcas[#marcas + 1] = b
end

local avisadas = {}
local function aplicar(evento, intento)
  quitarMarcas()
  if not WowF.recompensaActiva() then return nil end
  local d, pend = WowF.recompensaDecidir()
  if pend == "pendiente" and (intento or 1) < 3 and C_Timer and C_Timer.After then
    C_Timer.After(0.5, function() aplicar(evento, (intento or 1) + 1) end)
    if not d then return nil end
  end
  if not d then return nil end
  local b = botonDe(d.indice)
  if b then marcar(b, d.tipo, d.texto) end
  -- Al entregar la mision: una linea en el chat (una vez por mision)
  if evento == "QUEST_COMPLETE" then
    local clave = tostring(numero(llamar(GetQuestID)) or texto(llamar(GetTitleText)) or "") .. ":" .. d.link
    if not avisadas[clave] then
      avisadas[clave] = true
      print(PREFIJO .. L("recompensa: ", "reward: ") .. d.link .. " - " .. (d.tipo == "mejora" and VERDE or ORO) .. d.texto .. "|r" ..
        (d.porque and (": " .. d.porque) or "") .. GRIS .. L(" (tú eliges)", " (you choose)") .. "|r")
    end
  end
  return d, b
end
WowF.recompensaAplicar = aplicar
WowF._recompensaMarcas = function() return marcas end -- para las pruebas
WowF._recompensaOlvidar = function() avisadas = {} end -- para las pruebas

local ev = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_COMPLETE", "QUEST_DETAIL", "QUEST_FINISHED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  if evento == "QUEST_FINISHED" then quitarMarcas(); return end
  -- La ventana coloca los botones justo despues del evento
  if C_Timer and C_Timer.After then C_Timer.After(0.1, function() pcall(aplicar, evento) end)
  else pcall(aplicar, evento) end
end)

-- ===================== /wowf recompensa =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "recompensa" or orden == "reward" then
    local t = db()
    if resto == "off" or resto == "no" then t.recompensa = false elseif resto == "on" or resto == "si" then t.recompensa = true
    else t.recompensa = not WowF.recompensaActiva() end
    if not WowF.recompensaActiva() then quitarMarcas() end
    print(PREFIJO .. L("recompensa recomendada ", "quest reward advice ") .. (WowF.recompensaActiva() and (VERDE .. L("ENCENDIDA", "ON")) or (GRIS .. L("APAGADA", "OFF"))) .. "|r" ..
      L(". /wowf recompensa on|off", ". /wowf reward on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end

-- Casilla en Ajustes (wowF_Opciones.lua la dibuja si existe el registro)
if WowF.registrarCasillaOpciones then
  WowF.registrarCasillaOpciones("recompensa", function() return L("Marcar la mejor recompensa de misión", "Highlight the best quest reward") end)
end
