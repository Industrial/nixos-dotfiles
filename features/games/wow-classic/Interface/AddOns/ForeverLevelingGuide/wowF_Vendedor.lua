-- Forever Leveling Guide: que puedes vender al vendedor (5-oct-2026).
-- Al hablar con un vendedor (MERCHANT_SHOW) sale una ventanita al lado: "Puedes vender: N objetos (Xg)" con la lista.
-- Entra en la lista (solo lo que esta en tus BOLSAS: lo que llevas puesto nunca se mira):
--   * Grises (calidad Poor) que el vendedor compra. Si el juego ya trae su boton de vender basura (el de Forever), los grises
--     NO se repiten aqui: se vende con ese boton.
--   * Equipo blanco o verde que tu clase no puede llevar nunca, o que no mejora lo que llevas segun los pesos de tu rama
--     (WowF.compararPieza; solo si la comparacion es segura: si algo no se pudo leer, no entra).
-- Nunca entra: objetos de mision (o que empiezan una mision), Rare/Epic, verdes que se ligan al equiparlo sin precio de subasta
-- conocido, lo que vale mas en la casa de subastas (precio REAL de wowF_AvisoBotin: Auctionator, TSM o lo que viste), lo que
-- pide un nivel que aun no tienes y lo que esta en un conjunto de equipo.
-- "Vender estos" vende SOLO al hacer clic, y antes de vender cada objeto vuelve a comprobar que sigue en su sitio y que sigue
-- cumpliendo todo lo de arriba.
-- /wowf vendedor on|off (/wowf vendor on|off) y casilla en Ajustes. Encendido por defecto.
-- 11-oct: cada objeto con su icono y su boton "Vender"; "Reparar todo" con el precio si el vendedor repara
-- (y casilla en Ajustes para reparar solo al abrirlo, apagada por defecto).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, ORO, GRIS = "|cff1eff00", "|cffffd100", "|cff9d9d9d"
local MAX_LINEAS = 10

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
local function dinero(c)
  if WowF.avisoBotinDinero then return WowF.avisoBotinDinero(c) end
  return tostring(math.floor(c or 0)) .. "c"
end
local function marcar(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end

function WowF.vendedorActivo() return db().vendedor ~= false end
-- Las API que hacen falta: leer las bolsas y vender (C_Container moderno o las clasicas)
local function api()
  local C = C_Container
  local a = {
    huecos = (C and C.GetContainerNumSlots) or GetContainerNumSlots,
    info = (C and C.GetContainerItemInfo) or GetContainerItemInfo,
    enlace = (C and C.GetContainerItemLink) or GetContainerItemLink,
    mision = (C and C.GetContainerItemQuestInfo) or GetContainerItemQuestInfo,
    usar = (C and C.UseContainerItem) or UseContainerItem,
    conjunto = C and C.GetContainerItemEquipmentSetInfo,
  }
  if type(a.huecos) ~= "function" or type(a.info) ~= "function" or type(a.usar) ~= "function" then return nil end
  return a
end
function WowF.vendedorDisponible() return api() ~= nil and (type(GetItemInfo) == "function" or (C_Item and type(C_Item.GetItemInfo) == "function")) end
-- El boton de vender basura del propio juego (Forever lo trae): si existe, los grises no se repiten
function WowF.vendedorBasuraDelJuego()
  return (C_MerchantFrame and type(C_MerchantFrame.SellAllJunkItems) == "function") or _G.MerchantSellAllJunkButton ~= nil
end

-- GetItemInfo protegido (mismos campos que wowF_AvisoBotin.lua)
local function infoObjeto(link)
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

-- Lo que hay en una casilla de la bolsa: enlace, cantidad, sin valor, mision
local function casilla(a, bolsa, hueco)
  local r = { pcall(a.info, bolsa, hueco) }
  if not r[1] or r[2] == nil then return nil end
  local link, cuenta, sinValor, ligado
  if type(r[2]) == "table" then
    local t = r[2]
    link, cuenta, sinValor, ligado = texto(t.hyperlink), numero(t.stackCount), t.hasNoValue == true, t.isBound == true
  else
    link, cuenta, sinValor = texto(r[8]), numero(r[3]), r[10] == true
  end
  if not link and a.enlace then link = texto(llamar(a.enlace, bolsa, hueco)) end
  if not link then return nil end
  local mision = false
  if a.mision then
    local q = { pcall(a.mision, bolsa, hueco) }
    if q[1] then
      if type(q[2]) == "table" then mision = (q[2].isQuestItem == true) or (numero(q[2].questID) or 0) > 0
      else mision = (q[2] == true) or (numero(q[3]) or 0) > 0 end
    end
  end
  local enConjunto = false
  if a.conjunto then local ok, s = pcall(a.conjunto, bolsa, hueco); enConjunto = ok and s == true end
  return { link = link, cuenta = cuenta or 1, sinValor = sinValor, mision = mision, conjunto = enConjunto, ligado = ligado }
end

-- 5-oct (revision): herramientas de profesion. Son armas (Mining Pick, Skinning Knife, Fishing Pole...) pero hacen falta
-- para la profesion: nunca se venden. Subclases de arma 14 (Miscellaneous) y 20 (Fishing Poles) y estos ids.
-- 9-oct (regla de Andy: cero datos de Classic): la lista sale de los datos de Forever (WowFDatos.herramientas, de generar-plan-addon.js:
-- SpellTotems + TotemCategory de las recetas de Forever, y las canas de pescar). Si aun no esta generada, esta reserva: solo ids que
-- existen en ItemSparse de Forever (build 1.60.1.70291) y que Forever pide como herramienta (comprobado con SpellTotems/TotemCategory).
-- Fuera Finkle's Skinner (12709) y Darkwood Fishing Pole (6366): no estan en ItemSparse de Forever.
local HERRAMIENTAS = (WowFDatos and type(WowFDatos.herramientas) == "table" and next(WowFDatos.herramientas)) and WowFDatos.herramientas or {
  [2901] = true, [6206] = true, [259229] = true,                           -- Mining Pick, Rock Chipper, Vindael's Spectral Pickaxe
  [5956] = true, [285280] = true, [285281] = true,                         -- Blacksmith Hammer, Mithril/Arcanite Blacksmith Hammer
  [7005] = true, [269716] = true,                                          -- Skinning Knife, Keen Skinning Knife
  [6219] = true, [10498] = true, [4471] = true, [260811] = true,           -- Arclight Spanner, Gyromatic Micro-Adjustor, Flint and Tinder, Gnomish Army Knife
  [9149] = true, [13503] = true,                                           -- Philosopher's Stone, Alchemist's Stone
  [6256] = true, [6365] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- Fishing Poles
  [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- Runed Rods (Enchanting)
}
WowF.HERRAMIENTAS_PROFESION = HERRAMIENTAS
local SUB_HERRAMIENTA = { [14] = true, [20] = true }

-- Conjuntos de ItemRack y Outfitter (el juego solo avisa de los suyos, GetContainerItemEquipmentSetInfo).
-- ItemRack: se leen los ids de sus conjuntos (ItemRackUser.Sets[n].equip = { ranura = "id:..." }).
-- Outfitter, o un ItemRack que no se deja leer: no se sabe que piezas son de un conjunto, asi que no se vende ningun equipo.
local function addonCargado(nombre)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if type(f) == "function" then
    local ok, v = pcall(f, nombre)
    if ok and v then return true end
  end
  return false
end
local function conjuntosDeOtros()
  local ids, todo = {}, false
  if addonCargado("Outfitter") or type(_G.Outfitter) == "table" then todo = true end
  if addonCargado("ItemRack") or type(_G.ItemRackUser) == "table" then
    local u = _G.ItemRackUser
    local okL = pcall(function()
      if type(u) ~= "table" or type(u.Sets) ~= "table" then error("sin conjuntos") end
      for _, s in pairs(u.Sets) do
        if type(s) == "table" and type(s.equip) == "table" then
          for _, cadena in pairs(s.equip) do
            local id = tonumber(tostring(cadena):match("^(%d+)") or "")
            if id and id > 0 then ids[id] = true end
          end
        end
      end
    end)
    if not okL then todo = true end
  end
  return ids, todo
end

-- 5-oct (revision): lo que usa tu rama segun el plan (plan.mejores). Una pieza de una ranura que tu rama no usa
-- (un escudo con una rama DPS, un Held In Off-hand con un Warrior) no se vende como "no mejora": puede servir a otra rama.
-- Las armaduras de siempre (cabeza, pecho, anillos, capa...) las usan todas las ramas.
local ARMADURA_COMUN = { [1] = true, [2] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true,
  [11] = true, [12] = true, [16] = true, [20] = true }
local function deLaRama(plan, inv, sub)
  if ARMADURA_COMUN[inv] then return true end
  if type(plan) ~= "table" or type(plan.mejores) ~= "table" then return false end
  for _, m in ipairs(plan.mejores) do
    local n = type(m.nombre) == "string" and m.nombre or ""
    if inv == 14 and n == "Shield" then return true end
    if inv == 23 and n == "Held In Off-hand" then return true end
    if inv == 22 and n == "Off Hand" then return true end
    if inv == 17 and (n == "Two-Hand" or (sub == 10 and n:find("Staff", 1, true))) then return true end
    if (inv == 13 or inv == 21) and n:find("^Main Hand") then return true end
    if inv == 13 and n == "Off Hand" then return true end
    if inv == 15 or inv == 25 or inv == 26 then
      if sub == 19 and n == "Wand" then return true end
      if sub ~= 19 and n:find("^Ranged") then return true end
    end
    if inv == 28 and n:find("^Relic") then return true end
  end
  return false
end
WowF._vendedorDeLaRama = deLaRama -- para las pruebas

-- Lo que no cambia de un objeto a otro: se lee UNA vez por apertura del vendedor (plan, clase, nivel, conjuntos)
function WowF.vendedorContexto()
  local ctx = {}
  local okC, _, tk = pcall(UnitClass, "player")
  ctx.token = okC and texto(tk) or nil
  ctx.nivel = numero(llamar(UnitLevel, "player"))
  if WowF.armarPlan then
    local okP, plan = pcall(WowF.armarPlan)
    if okP and type(plan) == "table" and plan.pesos then ctx.plan = plan end
  end
  ctx.otrosConjuntos, ctx.conjuntosDudosos = conjuntosDeOtros()
  return ctx
end

-- La decision para un objeto de la bolsa. Devuelve el motivo (texto corto) si se puede vender, o nil.
-- c = casilla(...); grisesAparte = el juego ya trae su boton de basura; ctx = WowF.vendedorContexto() (si falta, se lee aqui)
function WowF.vendedorDecidir(c, grisesAparte, ctx)
  if type(c) ~= "table" or not c.link then return nil end
  if c.mision or c.conjunto or c.sinValor then return nil end
  local i = infoObjeto(c.link)
  if not i or not i.sell or i.sell <= 0 then return nil end
  if i.clase == 12 or i.bind == 4 then return nil end                     -- objeto de mision
  local id = idDe(c.link)
  if id and HERRAMIENTAS[id] then return nil end                           -- herramienta de profesion
  if i.clase == 2 and SUB_HERRAMIENTA[i.sub or -1] then return nil end      -- Miscellaneous / Fishing Poles
  ctx = ctx or WowF.vendedorContexto()
  if id and ctx.otrosConjuntos and ctx.otrosConjuntos[id] then return nil end -- en un conjunto de ItemRack
  if i.q == 0 then
    if grisesAparte then return nil end
    return L("gris", "gray")
  end
  if i.q >= 3 then return nil end                                          -- Rare/Epic: nunca
  if i.clase ~= 2 and i.clase ~= 4 then return nil end                     -- solo equipo
  if ctx.conjuntosDudosos then return nil end                              -- Outfitter: no se sabe que esta en un conjunto
  local inv = i.loc and WowF.INV_DE_LOC and WowF.INV_DE_LOC[i.loc]
  if not inv or inv == 18 or inv == 24 or inv == 27 or inv == 4 or inv == 19 then return nil end -- bolsa, municion, camisa, tabardo
  -- Lo que vale mas en la casa de subastas, no se le vende al vendedor
  if WowF.precioSubasta then
    local p = WowF.precioSubasta(c.link, id)
    if p and p > i.sell then return nil end
    -- Verde que se puede subastar y sin precio conocido: no se sabe si vale mas, mejor no
    if not p and i.q == 2 and i.bind ~= 1 and not c.ligado then return nil end
  elseif i.q == 2 and i.bind ~= 1 and not c.ligado then
    return nil
  end
  local token = ctx.token
  if not token or not WowF.nivelDeUso then return nil end
  local desde = WowF.nivelDeUso(token, i, inv)
  if not desde or desde > 60 then
    -- Solo los blancos: un verde de un tipo que tu clase no lleva puede valer para otro (subasta, otro personaje): se deja
    if i.q == 1 then return L("no es para tu clase", "not for your class") end
    return nil
  end
  local nivel = ctx.nivel
  if not nivel or desde > nivel then return nil end                        -- lo podras usar mas adelante: no se toca
  -- Tu clase lo lleva: solo si es de una ranura que usa tu rama, la comparacion con lo puesto es segura y dice que no mejora
  local plan = ctx.plan
  if not plan or not WowF.piezaDeEnlace or not WowF.compararPieza then return nil end
  if not deLaRama(plan, inv, i.sub) then return nil end
  local pieza = WowF.piezaDeEnlace(c.link)
  if not pieza or pieza.incierto then return nil end
  pieza.nivel = nil
  local ok, sirve, porque = pcall(WowF.compararPieza, pieza, plan)
  if not ok or sirve ~= false or porque ~= nil then return nil end
  return L("no mejora lo que llevas", "not an upgrade for you")
end

-- Recorre las bolsas. Devuelve { lista = {{bolsa, hueco, link, cuenta, valor, motivo}}, total, grisesAparte } o nil si no hay API
function WowF.vendedorRevisar()
  local a = api()
  if not a then return nil end
  local aparte = WowF.vendedorBasuraDelJuego()
  local r = { lista = {}, total = 0, grisesAparte = aparte }
  local ctx = WowF.vendedorContexto() -- una vez por apertura, no por objeto
  for bolsa = 0, (numero(NUM_BAG_SLOTS) or 4) do
    local n = numero(llamar(a.huecos, bolsa)) or 0
    for hueco = 1, n do
      local c = casilla(a, bolsa, hueco)
      if c then
        local motivo = WowF.vendedorDecidir(c, aparte, ctx)
        if motivo then
          local i = infoObjeto(c.link)
          local valor = (i.sell or 0) * (c.cuenta or 1)
          r.lista[#r.lista + 1] = { bolsa = bolsa, hueco = hueco, link = c.link, cuenta = c.cuenta, valor = valor, motivo = motivo }
          r.total = r.total + valor
        end
      end
    end
  end
  return r
end

-- ===================== La ventana =====================
-- 11-oct (calidad de vida, Andy): cada objeto en su fila con el ICONO, el nombre en su color, para que se vende y el precio,
-- y un boton "Vender" por fila. Abajo, "Vender todo". Pasar el raton por la fila = el tooltip del objeto de tu bolsa.
local FILAS, ALTO_FILA, ANCHO = 10, 30, 300
local marco, actual
local abierto = false

-- Icono del objeto (sin icono conocido: el signo de interrogacion del juego)
local function iconoDe(link)
  local id = idDe(link)
  local ic = id and (llamar(C_Item and C_Item.GetItemIconByID, id) or llamar(GetItemIcon, id))
  if ic == nil then
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(f) == "function" then local r = { pcall(f, link) }; if r[1] then ic = r[11] end end
  end
  if type(ic) ~= "number" and type(ic) ~= "string" then ic = "Interface\\Icons\\INV_Misc_QuestionMark" end
  return ic
end
WowF._vendedorIcono = iconoDe -- para las pruebas

-- Vende UN objeto de la lista (solo con el clic y con el vendedor abierto), comprobando antes que sigue igual
local function venderUno(o, ctx)
  if not abierto or not o or not WowF.vendedorActivo() then return false end
  local a = api()
  if not a then return false end
  local c = casilla(a, o.bolsa, o.hueco)
  if not (c and c.link == o.link and WowF.vendedorDecidir(c, actual and actual.grisesAparte, ctx or WowF.vendedorContexto())) then return false end
  return pcall(a.usar, o.bolsa, o.hueco) == true
end

-- Reparar (11-oct): lo que cuesta reparar todo aqui (0 = nada que reparar o este vendedor no repara)
local function costoReparar()
  -- 13-oct: tras reparar, el juego tarda un momento en poner el costo a 0; hasta volver a abrir el vendedor ya no hay nada que reparar
  if WowF._vendedorReparado then return 0 end
  if not numero(llamar(CanMerchantRepair)) and llamar(CanMerchantRepair) ~= true then return 0 end
  local ok, costo, puede = pcall(GetRepairAllCost)
  costo = ok and numero(costo) or 0
  if not ok or not puede or costo <= 0 then return 0 end
  return costo
end
WowF._vendedorCostoReparar = costoReparar
function WowF.vendedorAutoReparar() return db().autoReparar == true end
-- Repara todo (con el clic, o solo al abrir si esta encendido en Ajustes). Devuelve lo que costo, o nil si no se pudo.
function WowF.vendedorReparar(solo)
  if not abierto then return nil end
  local costo = costoReparar()
  if costo <= 0 then return nil end
  local dinero0 = numero(llamar(GetMoney))
  if dinero0 and dinero0 < costo then
    if not solo then print(PREFIJO .. marcar(L("no te alcanza para reparar todo: cuesta ", "not enough money to repair everything: it costs ") .. ORO .. dinero(costo) .. "|r.")) end
    return nil
  end
  if not pcall(RepairAllItems) then return nil end
  WowF._vendedorReparado = true
  if WowF.quitarAviso then pcall(WowF.quitarAviso, "durabilidad") end
  print(PREFIJO .. marcar(L("Reparado todo", "Repaired everything") .. " (" .. ORO .. dinero(costo) .. "|r)" .. (solo and L(" (automatico, se cambia en Ajustes).", " (automatic, change it in Settings).") or ".")))
  return costo
end

local function tooltipFila(f)
  local o = f.objeto
  if not o or not GameTooltip then return end
  pcall(GameTooltip.SetOwner, GameTooltip, f, "ANCHOR_LEFT")
  local ok = pcall(GameTooltip.SetBagItem, GameTooltip, o.bolsa, o.hueco)
  if not ok then pcall(GameTooltip.SetHyperlink, GameTooltip, o.link) end
  pcall(GameTooltip.Show, GameTooltip)
end
local function sinTooltip() if GameTooltip then pcall(GameTooltip.Hide, GameTooltip) end end

-- 11-oct (rediseno "hibrido"): cada fila = icono cuadrado con borde fino + nombre (en su color de calidad) + para que se vende
-- en gris debajo, el precio en gris a la derecha y "Vender" secundario; una raya gris fina separa las filas.
local E = WowF.estilo
local function crearFila(m, k)
  local f = CreateFrame("Button", nil, m)
  f:SetSize(ANCHO - 24, ALTO_FILA - 2)
  f.fondo = f:CreateTexture(nil, "BACKGROUND")
  f.fondo:SetAllPoints()
  if f.fondo.SetColorTexture then f.fondo:SetColorTexture(1, 1, 1, 0) end
  local luz = f:CreateTexture(nil, "HIGHLIGHT")
  luz:SetAllPoints()
  if luz.SetColorTexture then luz:SetColorTexture(1, 1, 1, 0.05) end
  f.marcoIcono = f:CreateTexture(nil, "ARTWORK", nil, 1)
  if f.marcoIcono.SetColorTexture then f.marcoIcono:SetColorTexture(E.color.borde[1], E.color.borde[2], E.color.borde[3], 1) end
  f.marcoIcono:SetSize(24, 24); f.marcoIcono:SetPoint("LEFT", 0, 0)
  f.icono = f:CreateTexture(nil, "ARTWORK", nil, 2)
  f.icono:SetSize(22, 22); f.icono:SetPoint("CENTER", f.marcoIcono, "CENTER", 0, 0)
  if f.icono.SetTexCoord then f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.cuenta = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  f.cuenta:SetPoint("BOTTOMRIGHT", f.marcoIcono, "BOTTOMRIGHT", 1, -1)
  f.nombre = E.cuerpo(f, nil, 11)
  f.nombre:SetPoint("TOPLEFT", f.marcoIcono, "TOPRIGHT", 8, 0); f.nombre:SetWidth(146)
  if f.nombre.SetWordWrap then f.nombre:SetWordWrap(false) end
  f.motivo = E.sub(f, nil, 9)
  f.motivo:SetPoint("BOTTOMLEFT", f.marcoIcono, "BOTTOMRIGHT", 8, 0); f.motivo:SetWidth(146)
  if f.motivo.SetWordWrap then f.motivo:SetWordWrap(false) end
  f.vender = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  E.boton(f.vender, "cuero", 10)
  f.vender:SetSize(52, 20); f.vender:SetPoint("RIGHT", 0, 0)
  f.precio = E.sub(f, nil, 10)
  f.precio:SetPoint("RIGHT", f.vender, "LEFT", -6, 0); f.precio:SetJustifyH("RIGHT")
  f.divisor = f:CreateTexture(nil, "ARTWORK", nil, 1)
  if f.divisor.SetColorTexture then f.divisor:SetColorTexture(E.color.borde[1], E.color.borde[2], E.color.borde[3], 1) end
  f.divisor:SetHeight(1)
  f.divisor:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0); f.divisor:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0)
  f:SetScript("OnEnter", tooltipFila)
  f:SetScript("OnLeave", sinTooltip)
  f.vender:SetScript("OnEnter", function() tooltipFila(f) end)
  f.vender:SetScript("OnLeave", sinTooltip)
  f.vender:SetScript("OnClick", function() WowF.vendedorVenderFila(f.indice) end)
  f:Hide()
  return f
end

local function crearMarco()
  if marco then return marco end
  marco = CreateFrame("Frame", "wowFVendedor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  marco:SetSize(ANCHO, 80)
  marco:SetFrameStrata("DIALOG")
  if marco.SetBackdrop then
    pcall(marco.SetBackdrop, marco, { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    pcall(marco.SetBackdropColor, marco, 0, 0, 0, 0.85)
  end
  E.marco(marco, "panel")
  -- Cabecera: franja oscura "FOREVER GUIDE" con el total a la derecha; debajo, el titulo en serif
  marco.cab = E.cabecera(marco, 22)
  marco.cab.titulo:SetText("Forever Guide")
  marco.cab.derecha:ClearAllPoints()
  marco.cab.derecha:SetPoint("RIGHT", marco.cab.fondo, "RIGHT", -28, 0)
  marco.titulo = E.titulo(marco, nil, 13)
  marco.titulo:SetPoint("TOPLEFT", 12, -36); marco.titulo:SetWidth(ANCHO - 24)
  if marco.titulo.SetWordWrap then marco.titulo:SetWordWrap(false) end
  -- Retrato redondo del vendedor (wowF_Retratos.lua) a la izquierda del titulo
  if WowF.marcoRetrato then
    marco.retrato = WowF.marcoRetrato(marco, 22)
    marco.retrato:SetPoint("TOPLEFT", 12, -31)
    marco.titulo:ClearAllPoints()
    marco.titulo:SetPoint("TOPLEFT", 40, -36); marco.titulo:SetWidth(ANCHO - 52)
  end
  marco.reparar = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
  E.boton(marco.reparar, "cuero", 11)
  marco.reparar:SetSize(ANCHO - 24, 22); marco.reparar:SetPoint("TOPLEFT", 12, -58)
  marco.reparar:SetScript("OnClick", function() if WowF.vendedorReparar() then WowF.vendedorMostrar() end end)
  marco.filas = {}
  for k = 1, FILAS do marco.filas[k] = crearFila(marco, k) end
  -- Nota de abajo: "y N mas" y los grises del boton del juego
  marco.lista = E.sub(marco, nil, 10)
  marco.lista:SetWidth(ANCHO - 24); marco.lista:SetJustifyH("LEFT")
  if marco.lista.SetSpacing then marco.lista:SetSpacing(2) end
  marco.boton = CreateFrame("Button", "wowFVendedorBoton", marco, "UIPanelButtonTemplate")
  E.boton(marco.boton, "brasa")
  marco.boton:SetSize(170, 24)
  marco.boton:SetPoint("BOTTOM", 0, 12)
  marco.boton:SetScript("OnClick", function() WowF.vendedorVender() end)
  -- Cerrar: la X pequena de cuero de las ventanas del rediseno (como la de la ruta)
  marco.cerrar = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
  E.boton(marco.cerrar, "cuero", 11)
  marco.cerrar:SetSize(18, 18)
  marco.cerrar:SetText("X")
  marco.cerrar:SetPoint("RIGHT", marco.cab.fondo, "RIGHT", -4, 0)
  marco.cerrar:SetScript("OnClick", function() marco:Hide() end)
  marco:Hide()
  return marco
end

-- Dibuja la lista actual (tambien tras vender una fila)
local function dibujar()
  local r, m = actual, marco
  if not m then return end
  local costo = abierto and costoReparar() or 0
  local n = r and #r.lista or 0
  if n == 0 and costo <= 0 then m:Hide(); return end
  -- Debajo de la cabecera (28 px) va el titulo en serif; luego Reparar (si hace falta) y las filas
  local arriba = 58
  if costo > 0 then
    m.reparar:SetText(marcar(L("Reparar todo", "Repair all") .. " (" .. dinero(costo) .. ")"))
    -- Si solo hay que reparar, Reparar es la accion principal (brasa); con objetos que vender, la principal es Vender todo
    E.boton(m.reparar, n == 0 and "brasa" or "cuero", 11)
    m.reparar:Show(); arriba = 88
  else m.reparar:Hide() end
  if n == 0 then
    m.titulo:SetText(L("Tu equipo necesita reparacion", "Your gear needs repairs"))
    m.cab.derecha:SetText("")
    for k = 1, FILAS do m.filas[k]:Hide() end
    m.lista:SetText(""); m.boton:Hide()
    m:SetHeight(arriba + 6)
    return
  end
  m.boton:Show()
  m.titulo:SetText(marcar(L("Puedes vender: ", "You can sell: ") .. n .. L(n == 1 and " objeto" or " objetos", n == 1 and " item" or " items") ..
    " (" .. ORO .. dinero(r.total) .. "|r)"))
  m.cab.derecha:SetText(tostring(n))
  local vistas = math.min(n, FILAS)
  for k = 1, FILAS do
    local f, o = m.filas[k], r.lista[k]
    if k <= vistas and o then
      f.indice, f.objeto = k, o
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", 12, -arriba - (k - 1) * ALTO_FILA)
      if k < vistas then f.divisor:Show() else f.divisor:Hide() end
      pcall(f.icono.SetTexture, f.icono, iconoDe(o.link))
      f.cuenta:SetText((o.cuenta or 1) > 1 and tostring(o.cuenta) or "")
      f.nombre:SetText(marcar(o.link))
      f.motivo:SetText(marcar(o.motivo))
      f.precio:SetText(marcar(dinero(o.valor or 0)))
      f.vender:SetText(L("Vender", "Sell"))
      f:Show()
    else
      f.indice, f.objeto = nil, nil
      f:Hide()
    end
  end
  local notas = {}
  if n > FILAS then notas[#notas + 1] = L("y " .. (n - FILAS) .. " mas (salen al vender estos)", "and " .. (n - FILAS) .. " more (shown as you sell these)") end
  if r.grisesAparte then notas[#notas + 1] = L("Los grises: con el boton de basura del vendedor.", "Gray items: use the vendor's junk button.") end
  m.lista:SetText(marcar(table.concat(notas, "\n")))
  m.lista:ClearAllPoints()
  m.lista:SetPoint("TOPLEFT", 12, -arriba - 4 - vistas * ALTO_FILA)
  m.boton:SetText(marcar(L("Vender todo", "Sell all") .. " (" .. dinero(r.total) .. ")"))
  m:SetHeight(arriba + 50 + vistas * ALTO_FILA + 14 * #notas)
end

function WowF.vendedorMostrar()
  if not WowF.vendedorActivo() then if marco then marco:Hide() end return nil end
  local r = WowF.vendedorRevisar()
  actual = r
  if (not r or #r.lista == 0) and costoReparar() <= 0 then if marco then marco:Hide() end return r end
  local m = crearMarco()
  dibujar()
  if not m:IsShown() and (not r or #r.lista == 0) and costoReparar() <= 0 then return r end
  m:ClearAllPoints()
  local padre = _G.MerchantFrame
  if padre and padre.IsShown and padre:IsShown() then m:SetPoint("TOPLEFT", padre, "TOPRIGHT", 4, -20)
  else m:SetPoint("TOP", UIParent, "TOP", 0, -140) end
  if m.retrato then pcall(m.retrato.poner, m.retrato, { unidad = "npc", npc = WowF.npcDeUnidad and WowF.npcDeUnidad("npc"), icono = "Interface\\Icons\\INV_Misc_Bag_10" }) end
  m:Show()
  return r
end
WowF.vendedorUltimo = function() return actual end
WowF._ventanaVendedor = function() return marco end

-- Vende la fila k (boton "Vender" de esa fila)
function WowF.vendedorVenderFila(k)
  local o = actual and actual.lista[k]
  if not o then return false end
  if not venderUno(o) then
    print(PREFIJO .. marcar(L("no se vendio ", "not sold ") .. o.link .. L(": ya no esta igual en tu bolsa.", ": it is no longer the same in your bag.")))
    table.remove(actual.lista, k); actual.total = math.max(0, actual.total - (o.valor or 0))
    dibujar()
    return false
  end
  print(PREFIJO .. marcar(L("Vendido: ", "Sold: ") .. o.link .. ((o.cuenta or 1) > 1 and (" x" .. o.cuenta) or "") .. " (" .. ORO .. dinero(o.valor or 0) .. "|r)."))
  table.remove(actual.lista, k); actual.total = math.max(0, actual.total - (o.valor or 0))
  dibujar()
  return true
end

-- Vende toda la lista (solo con el clic). Antes de cada venta comprueba que el objeto sigue ahi y que sigue cumpliendo todo.
function WowF.vendedorVender()
  if not abierto or not actual or not WowF.vendedorActivo() then return 0 end
  local a = api()
  if not a then return 0 end
  local vendidos, oro = 0, 0
  local ctx = WowF.vendedorContexto() -- el plan y lo demas, una sola vez para toda la venta
  for _, o in ipairs(actual.lista) do
    if venderUno(o, ctx) then vendidos = vendidos + 1; oro = oro + (o.valor or 0) end
  end
  print(PREFIJO .. marcar(L("Vendido: ", "Sold: ") .. vendidos .. L(vendidos == 1 and " objeto" or " objetos", vendidos == 1 and " item" or " items") ..
    " (" .. ORO .. dinero(oro) .. "|r)."))
  actual = nil
  if marco then marco:Hide() end
  return vendidos
end

local ev = CreateFrame("Frame")
-- 13-oct: tambien al reparar con el boton del juego (cambia la durabilidad o el oro): se redibuja y, si ya no queda nada, se cierra sola
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  if evento == "UPDATE_INVENTORY_DURABILITY" or evento == "PLAYER_MONEY" then
    if abierto and marco and marco:IsShown() then pcall(dibujar) end
    return
  end
  if evento == "MERCHANT_SHOW" then
    abierto = true
    WowF._vendedorReparado = nil
    if WowF.vendedorAutoReparar() then pcall(WowF.vendedorReparar, true) end
    pcall(WowF.vendedorMostrar)
  else abierto = false; actual = nil; if marco then marco:Hide() end end
end)

-- ===================== Avisos de bolsas y equipo (4.25) =====================
-- Bolsas casi llenas (2 huecos o menos) y equipo casi roto (20 % o menos): una alerta al cruzar el limite, no cada vez.
-- 13-oct (amigo de Andy con 8 huecos): las bolsas se miran SOLO al iniciar sesion, 10 s despues (al entrar al mundo el juego
-- aun no cargo todas las bolsas y contaba de menos), y solo si se pudo leer la mochila entera.
-- Casilla en Ajustes ("avisosInventario", encendida por defecto).
local HUECOS_AVISO, DURABILIDAD_AVISO = 2, 20
function WowF.avisosInventarioActivos() return db().avisosInventario ~= false end

-- Huecos libres en las bolsas normales (las de profesion no cuentan: ahi no cabe cualquier cosa)
function WowF.huecosLibres()
  local libres = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local tam = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  if type(libres) ~= "function" then return nil end
  -- mochila sin cargar (0 casillas) = no se sabe: mejor no avisar que avisar en falso
  if type(tam) == "function" then local ok, s = pcall(tam, 0); s = ok and numero(s); if not s or s <= 0 then return nil end end
  local total, alguna = 0, false
  for bolsa = 0, (numero(NUM_BAG_SLOTS) or 4) do
    local ok, n, tipo = pcall(libres, bolsa)
    n, tipo = ok and numero(n), ok and numero(tipo)
    if n and (tipo == nil or tipo == 0) then total = total + n; alguna = true end
  end
  return alguna and total or nil
end

-- Durabilidad mas baja de lo que llevas puesto, en % (nil = no se pudo leer o nada tiene durabilidad)
function WowF.durabilidadMinima()
  if type(GetInventoryItemDurability) ~= "function" then return nil end
  local minimo
  for hueco = 1, 18 do
    local ok, actual, maximo = pcall(GetInventoryItemDurability, hueco)
    actual, maximo = ok and numero(actual), ok and numero(maximo)
    if actual and maximo and maximo > 0 then
      local p = math.floor(actual * 100 / maximo + 0.5)
      if not minimo or p < minimo then minimo = p end
    end
  end
  return minimo
end

local bolsasAvisadas, equipoAvisado = false, false
function WowF.revisarBolsas()
  if not WowF.avisosInventarioActivos() or not WowF.avisar then return false end
  local n = WowF.huecosLibres()
  if not n then return false end
  if n > HUECOS_AVISO then bolsasAvisadas = false; return false end
  if bolsasAvisadas then return false end
  bolsasAvisadas = true
  local texto = n == 0 and L("No te queda ningun hueco: lo que caiga ya no lo recoges.", "No free slots left: you will not be able to loot anything else.")
    or L("Te quedan " .. n .. (n == 1 and " hueco." or " huecos."), "Only " .. n .. (n == 1 and " free slot left." or " free slots left."))
  if WowF.vendedorActivo() then
    local okR, r = pcall(WowF.vendedorRevisar)
    if okR and r and #r.lista > 0 then
      texto = texto .. "\n" .. GRIS .. L("En cualquier vendedor puedes vender " .. #r.lista .. (#r.lista == 1 and " objeto" or " objetos") .. " (" .. dinero(r.total) .. "): te lo marco al abrirlo.",
        "At any vendor you can sell " .. #r.lista .. (#r.lista == 1 and " item" or " items") .. " (" .. dinero(r.total) .. "): I will list them when you open it.") .. "|r"
    end
  end
  WowF.avisar(marcar(L("Bolsas casi llenas", "Bags almost full")), marcar(texto), nil, 8, nil, { clave = "bolsas" })
  return true
end
function WowF.revisarDurabilidad()
  if not WowF.avisosInventarioActivos() or not WowF.avisar then return false end
  local p = WowF.durabilidadMinima()
  if not p then return false end
  if p > DURABILIDAD_AVISO then
    -- 13-oct: ya reparado = fuera el aviso "Tu equipo se esta rompiendo" si sigue en pantalla
    if equipoAvisado and WowF.quitarAviso then pcall(WowF.quitarAviso, "durabilidad") end
    equipoAvisado = false; return false
  end
  if equipoAvisado then return false end
  equipoAvisado = true
  local texto = p == 0 and L("Una pieza ya esta rota: no te da nada hasta que la repares.", "One item is broken: it gives you nothing until you repair it.")
    or L("Una pieza esta al " .. p .. " %.", "One item is at " .. p .. "%.")
  texto = texto .. "\n" .. GRIS .. L("Reparala en un vendedor que repare (herreros y armeros); al abrirlo te sale el boton Reparar todo.",
    "Repair it at a vendor that repairs (blacksmiths and armorers); when you open it you get the Repair all button.") .. "|r"
  local reinf = WowF.notaLegacyDurabilidad and WowF.notaLegacyDurabilidad()
  if reinf then texto = texto .. "\n" .. VERDE .. reinf .. "|r" end
  WowF.avisar(marcar(L("Tu equipo se esta rompiendo", "Your gear is breaking")), marcar(texto), nil, 8, nil, { clave = "durabilidad" })
  return true
end

local evInv = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD" }) do pcall(evInv.RegisterEvent, evInv, e) end
evInv:SetScript("OnEvent", function(_, evento, inicio)
  -- bolsas: una sola vez al iniciar sesion (no en cada pantalla de carga ni mientras juegas)
  if evento == "PLAYER_ENTERING_WORLD" and inicio then
    if C_Timer and C_Timer.After then C_Timer.After(10, function() pcall(WowF.revisarBolsas) end) else pcall(WowF.revisarBolsas) end
  end
  pcall(WowF.revisarDurabilidad)
end)

-- Casilla en Ajustes (wowF_Opciones.lua)
if WowF.registrarCasillaOpciones then
  WowF.registrarCasillaOpciones("vendedor", function() return L("Vendedor: lista de lo que puedo vender", "Vendor: list of what I can sell") end)
  -- Apagada por defecto: gasta tu oro sin preguntar
  WowF.registrarCasillaOpciones("avisosInventario", function() return L("Avisarme si las bolsas se llenan o el equipo se rompe", "Warn me when my bags fill up or my gear is breaking") end)
  WowF.registrarCasillaOpciones("autoReparar", function() return L("Vendedor: reparar todo solo al abrirlo", "Vendor: repair everything automatically") end, true)
end

-- ===================== /wowf vendedor =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "vendedor" or orden == "vendor" then
    local t = db()
    if resto == "off" or resto == "no" then t.vendedor = false elseif resto == "on" or resto == "si" then t.vendedor = true
    else t.vendedor = not WowF.vendedorActivo() end
    if not WowF.vendedorActivo() and marco then marco:Hide() end
    local extra = ""
    if not WowF.vendedorDisponible() then extra = GRIS .. L(" (este cliente no deja leer las bolsas: no hara nada)", " (this client does not let addons read your bags: it will do nothing)") .. "|r" end
    print(PREFIJO .. L("lista de venta ", "vendor list ") .. (WowF.vendedorActivo() and (VERDE .. L("ENCENDIDO", "ON")) or (GRIS .. L("APAGADO", "OFF"))) .. "|r" ..
      extra .. L(". /wowf vendedor on|off", ". /wowf vendor on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
