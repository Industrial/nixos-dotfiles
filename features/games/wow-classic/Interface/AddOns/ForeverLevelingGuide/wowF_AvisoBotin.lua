-- Forever Leveling Guide: aviso de botin (4-oct-2026, pedido de Andy: "cuando te cae algo bueno, que te avise").
-- Cuando TE cae un objeto (de un enemigo o de una mision) decide solo, sin botones:
--   VERDE  "te sirve": tu clase lo puede usar y MEJORA lo que llevas segun los pesos de tu rama (WowF.compararPieza, la misma
--          comparacion del panel). Si aun no tienes el nivel (hasta 5 por encima): "guardalo, puedes usarlo al nivel N".
--   DORADO "no es para ti, pero vale": Rare/Epic que se liga al equiparlo (o un Uncommon que vale al menos 1 oro): "no es para
--          tu clase (es para X)" o "no mejora lo que llevas", con el precio. Precio de subasta SOLO si es real: Auctionator, TSM o
--          el minimo que TU viste en la casa de subastas (con su fecha). Si no, el precio exacto del vendedor (GetItemInfo).
--   Nada para basura, grises, blancos, consumibles normales ni lo que se liga al recogerlo y no te sirve.
-- Solo se afirma una mejora si se comparo de verdad con lo puesto; si algo no se pudo leer, se dice "comparalo tu".
-- Datos de apoyo: wowF_Valiosos.lua (generado: objetos que caen en el mundo en Forever, segun Wowhead /forever).
-- /wowf avisobotin on|off (tambien en Ajustes) y /wowf avisobotin sonido on|off. Encendido por defecto.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, ORO, GRIS = "|cff1eff00", "|cffffd100", "|cff9d9d9d"
local NIVELES_ANTES = 5          -- "guardalo" solo si lo podras usar dentro de 5 niveles
local MIN_VERDE = 10000          -- un Uncommon que no te sirve solo avisa si vale al menos 1 oro (precio real)
local REPETIR = 300              -- el mismo objeto no vuelve a avisar en 5 minutos
local CALLER = "Forever Leveling Guide"

-- Valores del juego: la beta devuelve algunos "secretos" (no se pueden leer ni unir en texto)
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
local function ahora() return numero(llamar(time)) or 0 end
local function db()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  return WowFExportarDB
end

function WowF.avisoBotinActivo() return db().avisoBotin ~= false end

-- ===================== Datos del objeto =====================
-- Todo lo de GetItemInfo, protegido. nil = el cliente aun no tiene el objeto en cache (se reintenta)
local function info(link)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, link) }
  if not r[1] or r[2] == nil then return nil end
  local i = { nombre = texto(r[2]), link = texto(r[3]) or link, q = numero(r[4]), rl = numero(r[6]) or 0, loc = texto(r[10]),
    sell = numero(r[12]), clase = numero(r[13]), sub = numero(r[14]), bind = numero(r[15]) }
  if not i.q then return nil end
  return i
end
local function idDe(link) return tonumber((link or ""):match("item:(%d+)") or "") end

-- ===================== Quien lo puede usar =====================
local SIN_TIPO = { [2] = true, [4] = true, [11] = true, [12] = true, [16] = true, [19] = true, [23] = true } -- igual que app.js
local NO_EQUIPO = { [18] = true, [24] = true, [27] = true, [4] = true, [19] = true } -- bolsa, municion, carcaj, camisa, tabardo: no se comparan
-- Nivel desde el que la clase (token, ej. "WARRIOR") puede llevarlo; nil = nunca (tipo de arma/armadura que no aprende)
local function nivelDeUso(token, i, inv)
  local c = WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[token]
  if not c then return nil end
  local prof
  if i.clase == 4 then
    if SIN_TIPO[inv] or i.sub == 0 then prof = 0 else prof = c.armaduras[i.sub] end
  elseif i.clase == 2 then
    if i.sub == 20 then prof = 0 else prof = c.armas[i.sub] end
  else
    prof = 0
  end
  if not prof then return nil end
  -- 12-oct (auditoria): 2.o valor = nivel en que tu clase APRENDE ese tipo (Mail al 40 para Shaman y Hunter), aparte del que pide el objeto
  return math.max(prof, i.rl or 0), prof
end
WowF.nivelDeUso = nivelDeUso
local function unir(lista)
  if #lista <= 1 then return lista[1] or "" end
  return table.concat(lista, ", ", 1, #lista - 1) .. L(" y ", " and ") .. lista[#lista]
end
-- "Warrior, Paladin y Hunter": las clases que lo pueden llevar a algun nivel (hasta 60)
local ORDEN = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function paraQuien(i, inv)
  local r = {}
  for _, tk in ipairs(ORDEN) do
    local n = nivelDeUso(tk, i, inv)
    local c = WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[tk]
    if n and n <= 60 and c then r[#r + 1] = c.en end
  end
  return r
end

-- ===================== Precios =====================
local function dinero(c)
  c = math.floor(c or 0)
  local g, s, co = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "g" end
  if s > 0 then t[#t + 1] = s .. "s" end
  if co > 0 or #t == 0 then t[#t + 1] = co .. "c" end
  return table.concat(t, " ")
end
WowF.avisoBotinDinero = dinero -- (no pisar WowF.dinero de wowF_Reinicio: ese escribe "1 oro 5 plata")
local function hace(dias)
  if dias == nil then return nil end
  dias = math.max(0, math.floor(dias))
  if dias == 0 then return L("hoy", "today") end
  if dias == 1 then return L("hace 1 dia", "1 day ago") end
  return L("hace " .. dias .. " dias", dias .. " days ago")
end

-- Precio de subasta REAL o nil. Devuelve cobre, de donde sale y su antiguedad (texto o nil)
local function precioSubasta(link, id)
  -- (a) Auctionator
  local A = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
  if type(A) == "table" then
    local p = numero(llamar(A.GetAuctionPriceByItemLink, CALLER, link)) or (id and numero(llamar(A.GetAuctionPriceByItemID, CALLER, id)))
    if p and p > 0 then
      local d = numero(llamar(A.GetAuctionAgeByItemLink, CALLER, link))
      return p, "Auctionator", hace(d)
    end
  end
  -- TSM
  local T = _G.TSM_API
  if type(T) == "table" and id then
    for _, fuente in ipairs({ "DBMinBuyout", "DBMarket" }) do
      local p = numero(llamar(T.GetCustomPriceValue, fuente, "i:" .. id))
      if p and p > 0 then return p, "TSM", nil end
    end
  end
  -- (b) Lo que el jugador vio en la casa de subastas
  local visto = id and type(db().preciosSubasta) == "table" and db().preciosSubasta[id]
  if type(visto) == "table" and numero(visto.p) and visto.p > 0 then
    local d = numero(visto.t) and (ahora() - visto.t) / 86400 or nil
    return visto.p, "visto", hace(d)
  end
  return nil
end
WowF.precioSubasta = precioSubasta

local function textoPrecio(i, link, id)
  local p, fuente, edad = precioSubasta(link, id)
  if p then
    local origen = (fuente == "visto") and L("lo viste", "you saw it") or fuente
    return L("En la casa de subastas: ", "At the auction house: ") .. ORO .. dinero(p) .. "|r (" .. origen .. (edad and (", " .. edad) or "") .. ").", p
  end
  local base
  if (i.sell or 0) > 0 then base = L("Al vendedor: ", "Vendor price: ") .. dinero(i.sell) .. "."
  else base = L("El vendedor no lo compra.", "Vendors do not buy it.") end
  if i.bind == 1 then return base, nil end -- se liga al recogerlo: no se puede subastar
  return base .. " " .. L("En la casa de subastas suele valer mas: miralo antes de venderselo al vendedor.",
    "It usually sells for more at the auction house: check there before selling it to a vendor."), nil
end

-- ===================== Guardalo para tu rama final (10-oct, 4.21) =====================
-- Andy: si la guia te hace subir con una rama y cambiar a otra (ej. Enhancement -> Elemental al 40), lo que te cae y le sirve a
-- la rama FINAL se avisa en AZUL: "guardalo para cuando pases a X (nivel N)". Vale para cualquier clase con plan mixto.
--   * Desde 5 niveles antes del cambio: si mejora (al menos un 5 %) lo que llevas, comparado con los pesos de la rama final.
--   * Antes: solo si es espectacular: esta en la lista BiS / pre-BiS de la rama final (foreverchanges.pro, wowF_BiS.lua) o es
--     Rare/Epic y mejora al menos un 25 % lo que llevas para la rama final.
-- Lo guardado se apunta por personaje (WowFExportarDB.guardadoFinal) y al llegar al nivel del cambio se recuerda.
-- Casilla en Ajustes (WowFExportarDB.avisoGuardarFinal) y /wowf avisobotin guardar on|off.
local AZUL = "|cff4fc3f7"
local MUY_BUENO = 0.25
function WowF.avisoGuardarActivo() return db().avisoGuardarFinal ~= false end
local function clavePj()
  local n = texto(llamar(UnitName, "player")) or "?"
  local reino = texto(llamar(GetRealmName)) or ""
  return reino ~= "" and (n .. "-" .. reino) or n
end
-- Esta en la lista BiS / pre-BiS (de tu faccion) de esa rama
local function enBiS(token, rama, id)
  local d = WowFBiS and token and rama and id and WowFBiS[token .. "|" .. rama]
  if type(d) ~= "table" then return false end
  local mia = WowF.bisEsMia or function() return true end
  for h, e in pairs(d) do
    if h ~= "_meta" and type(e) == "table" then
      if type(e.bis) == "table" and e.bis.id == id and mia(e.bis) then return true end
      if type(e.bisHorde) == "table" and e.bisHorde.id == id and mia(e.bisHorde) then return true end
      for _, pz in ipairs(e.prebis or {}) do if type(pz) == "table" and pz.id == id and mia(pz) then return true end end
    end
  end
  return false
end
WowF.avisoBotinEnBiS = enBiS
-- Devuelve el texto del aviso azul (y el porque corto) o nil
local function paraRamaFinal(i, id, pieza, plan, token, nivel, desde, nombre)
  if not WowF.avisoGuardarActivo() or type(plan) ~= "table" or not pieza or not WowF.compararPieza then return nil end
  local cambio, final = numero(plan.ramaCambio) or 0, texto(plan.ramaFinal)
  if cambio <= 0 or not final or type(plan.pesosFinal) ~= "table" or nivel >= cambio then return nil end
  if not desde or desde > math.max(cambio, nivel + NIVELES_ANTES) then return nil end
  local pf = setmetatable({ pesos = plan.pesosFinal, ramaPesos = final, manos = plan.manosFinal, daga = ((numero(plan.dagaFinal) or 0) > 0) and 1 or 0 }, { __index = plan })
  -- 12-oct (auditoria): la daga de la rama final rige YA para lo que guardas (p.daga es un nivel y aun no lo tienes); sin daga = 0, no heredar la de subida
  local ok, sirve, porque, segura, cuanto = pcall(WowF.compararPieza, pieza, pf)
  if not ok or not sirve or not porque or pieza.incierto then return nil end
  local bis = enBiS(token, final, id)
  -- cuanto = nil con segura: lo que llevas no vale nada para la rama final (o la ranura esta vacia) = mejora total
  local medible = segura and true or false
  local c = (type(cuanto) == "number") and cuanto or math.huge
  if nivel >= cambio - NIVELES_ANTES then
    if not (bis or (medible and c >= 0.05)) then return nil end
  elseif not (bis or (medible and (i.q or 0) >= 3 and c >= MUY_BUENO)) then
    return nil
  end
  local t = AZUL .. L("¡Guárdalo para " .. final .. "! ", "Save it for " .. final .. "! ") .. "|r" .. nombre ..
    L(" le servirá a tu rama final (" .. final .. ", cambias al nivel " .. cambio .. "): ", " will suit your final spec (" .. final .. ", you switch at level " .. cambio .. "): ") ..
    porque .. ". "
  if bis then t = t .. L("Está en la lista BiS de " .. final .. " (foreverchanges.pro). ", "It is on the " .. final .. " BiS list (foreverchanges.pro). ") end
  if desde > nivel and desde ~= cambio then t = t .. L("Pide nivel " .. desde .. ". ", "Requires level " .. desde .. ". ") end
  t = t .. AZUL .. L("No lo vendas: guárdalo (bolsas o banco) hasta el nivel " .. cambio .. ".", "Do not sell it: keep it (bags or bank) until level " .. cambio .. ".") .. "|r"
  return t, porque, { final = final, cambio = cambio }
end
local ultimoGuardar
local function apuntarGuardado(link, g)
  if type(g) ~= "table" then return end
  local t = db()
  if type(t.guardadoFinal) ~= "table" then t.guardadoFinal = {} end
  local k = clavePj()
  local e = t.guardadoFinal[k]
  if type(e) ~= "table" or e.final ~= g.final then e = { final = g.final, cambio = g.cambio, items = {} }; t.guardadoFinal[k] = e end
  e.cambio = g.cambio
  local id = idDe(link)
  for _, it in ipairs(e.items) do if it.id == id then return end end
  if #e.items < 20 then table.insert(e.items, { id = id, link = link }) end
end
WowF._avisoBotinClavePj = clavePj -- para las pruebas

-- ===================== La decision =====================
-- Devuelve tipo ("sirve" | "guardar" | "vende" | nil), el texto del aviso (con el enlace) y el porque corto (para el cartel).
-- nil, nil, "pendiente" = el cliente aun no tiene el objeto (reintentar).
function WowF.avisoBotinDecidir(link)
  link = texto(link)
  if not link then return nil end
  local i = info(link)
  if not i then return nil, nil, "pendiente" end
  if WowF.campamentoBotin then local ct, cc = WowF.campamentoBotin(idDe(link), i.link or link); if ct then return "sirve", ct, cc end end -- 8-oct: Blueprint de tu profesion (wowF_Campamento.lua)
  if i.q < 2 then return nil end                                    -- gris y blanco: nada
  local id = idDe(link)
  local dato = WowFValiosos and WowFValiosos.o and id and WowFValiosos.o[id]
  local nombre = i.link or link
  local inv = (i.loc and WowF.INV_DE_LOC and WowF.INV_DE_LOC[i.loc]) or (dato and dato.inv) or nil
  local valioso = (i.q >= 3 and i.bind == 2)                        -- Rare/Epic que se liga al equiparlo
  local function vende(motivo)
    local precio, subasta = textoPrecio(i, link, id)
    if not valioso then
      -- Uncommon (o lo que se liga al recogerlo): solo si su precio real llega a 1 oro
      if i.bind == 1 or i.q < 2 then return nil end
      local real = subasta or i.sell or 0
      if real < MIN_VERDE then return nil end
    end
    return "vende", ORO .. L("Objeto que vale: ", "Valuable item: ") .. "|r" .. nombre .. " " .. motivo .. " " .. precio
  end

  -- No es equipo (receta, bolsa, objeto de comercio...): solo si vale
  if not inv or NO_EQUIPO[inv] then
    if i.clase == 0 and not valioso then return nil end            -- consumible normal
    if i.clase == 12 then return nil end                           -- objeto de mision
    return vende(L("se puede vender.", "can be sold."))
  end

  local okC, _, tk = pcall(UnitClass, "player")  -- (no usar "UnitClass and UnitClass(...)": deja el 2.o valor en nil)
  local token = okC and texto(tk) or nil
  local nivel = numero(llamar(UnitLevel, "player")) or 1
  local desde = token and nivelDeUso(token, i, inv)

  if not desde or desde > 60 then
    local quien = paraQuien(i, inv)
    local para = (#quien > 0) and L(" (es para " .. unir(quien) .. ")", " (it is for " .. unir(quien) .. ")") or ""
    return vende(L("no es para tu clase" .. para .. ", pero puedes venderlo.", "is not for your class" .. para .. ", but you can sell it."))
  end
  -- 12-oct (auditoria: Mail a un Shaman de 16): tu clase aprende ese tipo despues del tope de la beta, o el objeto pide mas
  -- nivel que el tope: hoy no lo puedes llevar. Nunca "te sirve" ni "guardalo".
  if WowF.usoDeClase then
    local okP, okU, _, motivo = pcall(WowF.usoDeClase, { cl = i.clase, s = i.sub, nivel = i.rl or 0, link = link, id = id }, inv, nivel) -- 12-oct: con pcall
    if not okP then okU, motivo = true, nil end
    if not okU and motivo then
      return vende(L("no te sirve hoy: " .. motivo .. ". Puedes venderlo.", "is not usable for you yet: " .. motivo .. ". You can sell it."))
    end
  end
  -- Tu clase lo puede usar: comparar con lo que llevas (pesos de tu rama)
  local pieza = WowF.piezaDeEnlace and WowF.piezaDeEnlace(link)
  if not pieza and dato then pieza = { inv = inv, st = dato.st, ar = dato.ar or 0, dps = dato.dps or 0, id = id } end
  local plan = WowF.armarPlan and select(2, pcall(WowF.armarPlan)) or nil
  if pieza then pieza.nivel = nil end -- el nivel lo dice este aviso
  -- 10-oct (4.21): le sirve a la rama final de tu plan mixto -> aviso azul "guardalo"
  local function guardar()
    local g, gp, gi = paraRamaFinal(i, id, pieza, plan, token, nivel, desde, nombre)
    if g then ultimoGuardar = gi; return "guardar", g, gp end
    return nil
  end
  if desde > nivel + NIVELES_ANTES then
    local gt, g, gp = guardar(); if gt then return gt, g, gp end
    return vende(L("pide nivel " .. desde .. ": para entonces tendras algo mejor. Puedes venderlo.",
      "requires level " .. desde .. ": by then you will have something better. You can sell it."))
  end
  if not pieza or type(plan) ~= "table" or not plan.pesos or not WowF.compararPieza then
    if valioso then return vende(L("puede servirte, pero no se pudo comparar con lo que llevas: comparalo tu. Si no te sirve, puedes venderlo.",
      "may suit you, but it could not be compared with what you wear: compare it yourself. If you do not need it, you can sell it.")) end
    return nil
  end
  local ok, sirve, porque, segura, cuanto, det = pcall(WowF.compararPieza, pieza, plan)
  if not ok then sirve, porque, segura, det = false, nil, false, nil end
  -- 4-oct: "te sirve" solo si mejora al menos un 5 % (Andy: que sea bueno de verdad); menos = como si no mejorara
  if sirve and segura and type(cuanto) == "number" and cuanto < 0.05 then sirve = false end
  if sirve and porque and segura then
    if desde > nivel then
      return "sirve", VERDE .. L("¡Buen objeto! ", "Good item! ") .. "|r" .. nombre .. L(" te servira: ", " will suit you: ") .. porque .. ". " ..
        VERDE .. L("Guardalo: puedes usarlo al nivel " .. desde .. ".", "Keep it: you can use it at level " .. desde .. ".") .. "|r", porque
    end
    return "sirve", VERDE .. L("¡Buen objeto! ", "Good item! ") .. "|r" .. nombre .. L(" te sirve: ", " is an upgrade for you: ") .. porque .. ". " ..
      VERDE .. L("Equipalo.", "Equip it.") .. "|r", porque
  end
  do local gt, g, gp = guardar(); if gt then return gt, g, gp end end
  -- 7-oct: mejora pequena (pierdes algo que cuenta y casi se compensa): nunca en verde; si vale dinero, se dice con el porque corto
  if sirve and type(det) == "table" and det.dudosa and not pieza.incierto then
    local corto = WowF.porQueMejora and WowF.porQueMejora(det)
    if valioso then return vende(L("es una mejora pequeña para ti, depende" .. (corto and (": " .. corto) or "") .. ". Si no la quieres, puedes venderlo.",
      "is a small upgrade for you, it depends" .. (corto and (": " .. corto) or "") .. ". If you do not want it, you can sell it.")) end
    return nil
  end
  if sirve then
    -- Parece mejor pero algo no se pudo leer: no se afirma
    if valioso then return vende(L("puede ser una mejora, pero " .. ((porque or ""):gsub("^%u", string.lower)) .. ". Si no te sirve, puedes venderlo.",
      "may be an upgrade, but " .. ((porque or ""):gsub("^%u", string.lower)) .. ". If you do not need it, you can sell it.")) end
    return nil
  end
  if pieza.incierto then
    if valioso then return vende(L("tiene un efecto que el addon no puede valorar: comparalo tu. Si no te sirve, puedes venderlo.",
      "has an effect the addon cannot rate: compare it yourself. If you do not need it, you can sell it.")) end
    return nil
  end
  local rama = plan.ramaPesos or plan.ramaNombre
  return vende(L("no mejora lo que llevas" .. (rama and (" (rama " .. rama .. ")") or "") .. ", pero puedes venderlo.",
    "is not an upgrade for you" .. (rama and (" (" .. rama .. " spec)") or "") .. ", but you can sell it."))
end

-- ===================== El aviso en pantalla =====================
local cartel, ultimo
-- 5-oct (Andy: a un amigo se le quito muy rapido): el aviso NO se quita solo. Se queda hasta que lo cierras (X o boton),
-- se arrastra a cualquier sitio (la posicion se guarda en WowFExportarDB.avisoBotinPos) y crece con el texto.
-- Si caen varios objetos seguidos, se ponen en fila: el boton dice "Siguiente (N mas)" y no se pierde ninguno.
local cola = {}
local ANCHO_CARTEL = 440
local function colocarCartel(c)
  c:ClearAllPoints()
  local g = db().avisoBotinPos
  if type(g) == "table" and type(g[1]) == "string" and type(g[2]) == "string" and type(g[3]) == "number" and type(g[4]) == "number" then
    c:SetPoint(g[1], UIParent, g[2], g[3], g[4])
  else
    c:SetPoint("TOP", UIParent, "TOP", 0, -260)
  end
end
local turnoCartel = 0
local function pintarCartel()
  local c = cartel
  if not c then return end
  local actual = cola[1]
  if not actual then c:Hide() return end
  local titulo = (actual.tipo == "sirve" and L("¡Buen objeto!", "Good item!")) or (actual.tipo == "guardar" and L("Guárdalo para tu rama final", "Save it for your final spec"))
    or (actual.tipo == "recordar" and L("Ya cambias de rama", "Time to switch spec")) or L("Objeto que vale", "Valuable item")
  local color = (actual.tipo == "sirve" and VERDE) or ((actual.tipo == "guardar" or actual.tipo == "recordar") and AZUL) or ORO
  -- 11-oct (hibrido): la cabecera lleva "Forever Guide · <tipo>" (Cinzel, mayusculas) con el tipo en su color
  c.titulo:SetText("Forever Guide · " .. color .. titulo .. "|r")
  c.cab.derecha:SetText(#cola > 1 and ("1/" .. #cola) or "")
  -- fila con el icono del objeto (el recordatorio no trae un solo objeto: sin fila)
  local arriba = 40
  if type(actual.link) == "string" then
    local id = tonumber(actual.link:match("item:(%d+)"))
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    local ic = (id and type(f) == "function") and llamar(f, id) or nil
    -- 12-oct: icono del MISMO objeto del aviso, primero del cliente (wowF_Iconos.lua); lo leido arriba queda de respaldo
    if id and WowF.iconoObjeto then ic = WowF.iconoObjeto(id, ic) or ic end
    c.fila:poner(ic or "Interface\\Icons\\INV_Misc_QuestionMark", actual.link, nil)
    c.fila.nombre:ClearAllPoints()
    c.fila.nombre:SetPoint("LEFT", c.fila.marcoIcono, "RIGHT", 8, 0)
    c.fila.nombre:SetPoint("RIGHT", c.fila, "RIGHT", 0, 0)
    c.fila:Show(); c.divisor:Show()
    arriba = 88
  else
    c.fila:Hide(); c.divisor:Hide()
  end
  c.texto:ClearAllPoints()
  c.texto:SetPoint("TOPLEFT", 16, -arriba)
  c.texto:SetWidth(ANCHO_CARTEL - 32)
  c.texto:SetText((actual.t:gsub("^|c%x%x%x%x%x%x%x%x[^|]*|r", "")))
  local resto = #cola - 1
  c.boton:SetText(resto > 0 and L("Siguiente (" .. resto .. " más)", "Next (" .. resto .. " more)") or L("Cerrar", "Close"))
  local alto = numero(llamar(c.texto.GetStringHeight, c.texto)) or 40
  c:SetHeight(math.max(140, math.floor(alto) + arriba + 58))
  -- 13-oct (Ajustes > Avisos emergentes): tamano propio; si se eligio una duracion, este aviso se cierra solo (y sale el siguiente)
  if WowF.escalaPopup then WowF.escalaPopup(c, "wowFAvisoBotin") end
  local dura = WowF.duracionPopup and WowF.duracionPopup(nil)
  c.pista:SetText(dura and L("Arrástralo para moverlo. Se cierra solo en " .. dura .. " s.", "Drag it to move it. It closes by itself in " .. dura .. " s.")
    or L("Arrástralo para moverlo. Se queda hasta que lo cierres.", "Drag it to move it. It stays until you close it."))
  turnoCartel = turnoCartel + 1 -- 18-oct: contador propio (no un campo del marco)
  local miTurno, este = turnoCartel, actual
  if dura and C_Timer and C_Timer.After then
    C_Timer.After(dura, function()
      if turnoCartel ~= miTurno or not c:IsShown() or cola[1] ~= este then return end
      table.remove(cola, 1); pintarCartel()
    end)
  end
  c:Show()
end
local function crearCartel()
  if cartel then return cartel end
  cartel = CreateFrame("Frame", "wowFAvisoBotin", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  cartel:SetSize(ANCHO_CARTEL, 130)
  colocarCartel(cartel)
  cartel:SetFrameStrata("DIALOG")
  cartel:SetClampedToScreen(true)
  cartel:SetMovable(true)
  cartel:EnableMouse(true)
  cartel:RegisterForDrag("LeftButton")
  cartel:SetScript("OnDragStart", function(self) self:StartMoving() end)
  cartel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local a, _, b, x, y = self:GetPoint()
    if type(a) == "string" and type(b) == "string" then db().avisoBotinPos = { a, b, x, y } end
  end)
  -- 11-oct (hibrido): fondo de piedra, cabecera pequena, fila con el icono del objeto, texto Signika y pista gris
  local E = WowF.estilo
  E.marco(cartel, "aviso")
  cartel.cab = E.cabecera(cartel, 22)
  cartel.cab.derecha:ClearAllPoints()
  cartel.cab.derecha:SetPoint("RIGHT", cartel.cab.fondo, "RIGHT", -28, 0)
  cartel.titulo = cartel.cab.titulo
  cartel.fila = E.fila(cartel, ANCHO_CARTEL - 32, 30)
  cartel.fila:SetPoint("TOPLEFT", 16, -40)
  if cartel.fila.EnableMouse then cartel.fila:EnableMouse(false) end -- se arrastra el cartel entero
  cartel.divisor = E.divisor(cartel, cartel.fila, -6, 0, 16)
  cartel.texto = E.cuerpo(cartel, nil, 12)
  cartel.texto:SetPoint("TOPLEFT", 16, -40)
  cartel.texto:SetWidth(ANCHO_CARTEL - 32)
  cartel.texto:SetJustifyH("LEFT")
  if cartel.texto.SetSpacing then cartel.texto:SetSpacing(2) end
  cartel.pista = E.sub(cartel, nil, 10)
  cartel.pista:SetPoint("BOTTOMLEFT", 16, 18)
  cartel.pista:SetText(L("Arrástralo para moverlo. Se queda hasta que lo cierres.", "Drag it to move it. It stays until you close it."))
  cartel.boton = CreateFrame("Button", nil, cartel, "UIPanelButtonTemplate")
  E.boton(cartel.boton, "brasa")
  cartel.boton:SetSize(150, 24)
  cartel.boton:SetPoint("BOTTOMRIGHT", -14, 12)
  cartel.boton:SetScript("OnClick", function() table.remove(cola, 1); pintarCartel() end) -- cierra este; si hay mas, ensena el siguiente
  cartel.cerrar = CreateFrame("Button", nil, cartel, "UIPanelButtonTemplate")
  E.boton(cartel.cerrar, "cuero", 11)
  cartel.cerrar:SetSize(18, 18)
  cartel.cerrar:SetText("X")
  cartel.cerrar:SetPoint("RIGHT", cartel.cab.fondo, "RIGHT", -4, 0)
  cartel.cerrar:SetScript("OnClick", function() cola = {}; cartel:Hide() end) -- la X cierra todos
  cartel:Hide()
  return cartel
end

local vistos = {}
function WowF.avisoBotinMostrar(link)
  if not WowF.avisoBotinActivo() then return nil end
  ultimoGuardar = nil
  local tipo, t, extra = WowF.avisoBotinDecidir(link)
  if extra == "pendiente" then return "pendiente" end
  if not tipo or not t then return nil end
  local clave = (link or ""):match("|H(item:[^|]+)|h") or link
  local t0 = ahora()
  if vistos[clave] and t0 - vistos[clave] < REPETIR then return nil end
  vistos[clave] = t0
  ultimo = t
  if tipo == "guardar" then apuntarGuardado(link, ultimoGuardar) end
  print(PREFIJO .. t)
  local c = crearCartel()
  if not c:IsShown() then cola = {} end -- cerrado a mano: lo viejo ya se leyo
  table.insert(cola, { tipo = tipo, t = t, link = link })
  local o = WowF.opciones and WowF.opciones() -- el tamano de Ajustes (sin tocar la lista de ventanas de wowF_Opciones)
  if type(o) == "table" and type(o.tamano) == "number" and c.SetScale then pcall(c.SetScale, c, WowF.escalaVentana and WowF.escalaVentana("wowFAvisoBotin") or o.tamano) end
  pintarCartel()
  if db().avisoBotinSonido ~= false and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_BACKPACK_COIN_SELECT) or 865) end
  return tipo
end
-- 10-oct (4.21): al llegar al nivel del cambio, recordar lo que guardaste para la rama final (solo lo que aun tienes)
local function cuantos(id)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  if type(f) ~= "function" or not id then return nil end
  return numero(llamar(f, id, true))
end
function WowF.avisoGuardadoRecordar(nivel)
  local t = db()
  local k = clavePj()
  local e = type(t.guardadoFinal) == "table" and t.guardadoFinal[k] or nil
  nivel = numero(nivel) or numero(llamar(UnitLevel, "player")) or 0
  if type(e) ~= "table" or not numero(e.cambio) or nivel < e.cambio then return nil end
  t.guardadoFinal[k] = nil
  local lista = {}
  for _, it in ipairs(e.items or {}) do
    local n = cuantos(it.id)
    if (n == nil or n > 0) and type(it.link) == "string" then lista[#lista + 1] = it.link end
  end
  if #lista == 0 then return nil end
  local msg = AZUL .. L("¡Ya cambias a " .. e.final .. "! ", "Time to switch to " .. e.final .. "! ") .. "|r" ..
    L("Equipa lo que guardaste para " .. e.final .. ": ", "Equip what you saved for " .. e.final .. ": ") .. unir(lista) ..
    L(" (en tus bolsas o en el banco).", " (in your bags or bank).")
  print(PREFIJO .. msg)
  local c = crearCartel()
  if not c:IsShown() then cola = {} end
  table.insert(cola, { tipo = "recordar", t = msg })
  pintarCartel()
  return msg
end
WowF._avisoBotinCola = function() return #cola end -- para las pruebas
WowF.avisoBotinUltimo = function() return ultimo end
WowF._cartelAvisoBotin = function() return cartel end -- para las pruebas
WowF._avisoBotinOlvidar = function() vistos = {}; ultimo = nil end -- para las pruebas

-- ===================== Escuchar el botin propio =====================
-- Patrones de los mensajes "Recibes botin: %s." / "Recibes objeto: %s." del cliente (en su idioma). NO: lo creado por ti
-- (LOOT_ITEM_CREATED_SELF) ni lo que compras al vendedor (mismo mensaje que "recibes objeto": se ignora con el vendedor abierto).
local patrones
local function hacerPatrones()
  patrones = {}
  for _, n in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }) do
    local f = texto(_G[n])
    if f then
      -- %s y %d (tambien %1$s) -> marcas; escapar lo demas; marcas -> capturas
      local p = f:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
      p = p:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
      p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
      patrones[#patrones + 1] = "^" .. p .. "$"
    end
  end
  if #patrones == 0 then patrones = { "^You receive loot: (.+)%.$", "^You receive item: (.+)%.$" } end
end
local vendedor = false
function WowF.avisoBotinMensaje(msg)
  msg = texto(msg)
  if not msg or vendedor then return nil end
  if not patrones then hacerPatrones() end
  for _, p in ipairs(patrones) do
    local cosa = msg:match(p)
    if cosa then
      local link = cosa:match("|c[^|]*|Hitem:.-|h|r") or cosa:match("|Hitem:.-|h.-|h")
      if not link then return nil end
      local function intentar(n)
        local r = WowF.avisoBotinMostrar(link)
        if r == "pendiente" and n < 3 and C_Timer and C_Timer.After then C_Timer.After(1, function() intentar(n + 1) end) end
      end
      intentar(1)
      return link
    end
  end
  return nil
end

-- ===================== Precios que ves en la casa de subastas =====================
-- Se guarda el minimo (por unidad, con compra directa) de cada objeto que aparece en tus busquedas, con la fecha.
local function guardarPrecio(id, p)
  id, p = numero(id), numero(p)
  if not id or not p or p <= 0 then return end
  local t = db()
  if type(t.preciosSubasta) ~= "table" then t.preciosSubasta = {} end
  local hoy, v = ahora(), t.preciosSubasta[id]
  -- en la misma busqueda (menos de 10 min) se queda el minimo; despues, el precio nuevo reemplaza al viejo
  if type(v) == "table" and numero(v.t) and hoy - v.t < 600 and numero(v.p) and v.p <= p then return end
  t.preciosSubasta[id] = { p = p, t = hoy }
end
WowF.avisoBotinGuardarPrecio = guardarPrecio
local function leerSubastaClasica()
  if type(GetNumAuctionItems) ~= "function" or type(GetAuctionItemInfo) ~= "function" then return end
  local n = numero(llamar(GetNumAuctionItems, "list")) or 0
  local minimo = {}
  for i = 1, math.min(n, 200) do
    local r = { pcall(GetAuctionItemInfo, "list", i) }
    if r[1] then
      local cuenta, compra, id = numero(r[4]), numero(r[11]), numero(r[18])
      if id and compra and compra > 0 and cuenta and cuenta > 0 then
        local u = math.floor(compra / cuenta)
        if not minimo[id] or u < minimo[id] then minimo[id] = u end
      end
    end
  end
  for id, p in pairs(minimo) do guardarPrecio(id, p) end
end
local function leerSubastaModerna(evento, a1)
  local AH = C_AuctionHouse
  if type(AH) ~= "table" then return end
  if evento == "BROWSE_RESULTS_UPDATED" or evento == "BROWSE_RESULTS_ADDED" then
    local l = llamar(AH.GetBrowseResults)
    if type(l) == "table" then
      for _, r in ipairs(l) do if type(r) == "table" and type(r.itemKey) == "table" then guardarPrecio(r.itemKey.itemID, r.minPrice) end end
    end
  elseif evento == "ITEM_SEARCH_RESULTS_UPDATED" and type(a1) == "table" then
    local r = llamar(AH.GetItemSearchResultInfo, a1, 1)
    if type(r) == "table" then guardarPrecio(a1.itemID, r.buyoutAmount) end
  elseif evento == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    local r = llamar(AH.GetCommoditySearchResultInfo, a1, 1)
    if type(r) == "table" then guardarPrecio(a1, r.unitPrice) end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_LOOT", "MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "BROWSE_RESULTS_UPDATED",
  "BROWSE_RESULTS_ADDED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "PLAYER_LEVEL_UP" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento, a1)
  if evento == "CHAT_MSG_LOOT" then pcall(WowF.avisoBotinMensaje, a1)
  elseif evento == "PLAYER_LEVEL_UP" then pcall(WowF.avisoGuardadoRecordar, a1)
  elseif evento == "MERCHANT_SHOW" then vendedor = true
  elseif evento == "MERCHANT_CLOSED" then vendedor = false
  elseif evento == "AUCTION_ITEM_LIST_UPDATE" then pcall(leerSubastaClasica)
  else pcall(leerSubastaModerna, evento, a1) end
end)

if WowF.registrarCasillaOpciones then
  WowF.registrarCasillaOpciones("avisoGuardarFinal", function() return L("Avisarme de lo que guardar para mi rama final (planes que cambian de rama)", "Alert me about items to save for my final spec (plans that switch spec)") end)
end

-- ===================== /wowf avisobotin =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "avisobotin" or orden == "lootalert" then
    local t = db()
    local sub, valor = resto:match("^(%S*)%s*(%S*)$")
    if sub == "guardar" or sub == "save" then
      if valor == "off" or valor == "no" then t.avisoGuardarFinal = false elseif valor == "on" or valor == "si" then t.avisoGuardarFinal = true
      else t.avisoGuardarFinal = not WowF.avisoGuardarActivo() end
      print(PREFIJO .. L("aviso de guardar para tu rama final: ", "save-for-final-spec alert: ") .. (WowF.avisoGuardarActivo() and "on" or "off"))
      return
    end
    if sub == "sonido" or sub == "sound" then
      if valor == "off" or valor == "no" then t.avisoBotinSonido = false elseif valor == "on" or valor == "si" then t.avisoBotinSonido = true end
      print(PREFIJO .. L("sonido del aviso de botin: ", "loot alert sound: ") .. ((t.avisoBotinSonido ~= false) and "on" or "off"))
      return
    end
    if resto == "off" or resto == "no" then t.avisoBotin = false elseif resto == "on" or resto == "si" then t.avisoBotin = true
    else t.avisoBotin = not WowF.avisoBotinActivo() end
    print(PREFIJO .. L("aviso de botin ", "loot alert ") .. (WowF.avisoBotinActivo() and (VERDE .. L("ENCENDIDO", "ON")) or (GRIS .. L("APAGADO", "OFF"))) .. "|r" ..
      L(". /wowf avisobotin on|off", ". /wowf lootalert on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
