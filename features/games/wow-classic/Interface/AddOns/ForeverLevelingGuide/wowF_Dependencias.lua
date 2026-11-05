-- Forever Leveling Guide: dependencias entre profesiones (8-oct-2026, punto 6 de la investigacion de profesiones de Forever).
-- Con el objetivo "ganar oro", la pestana Profesiones dice:
--   VENDE:   "Tu <profesion> produce X, que lo piden N recetas de <otras profesiones>: vendelo."  (y cuantas Waylaid Crates lo piden)
--   COMPRA:  "Para fabricar <receta> necesitas X de <profesion>: compralo o pide a alguien."
-- Recetas que cuentan: las nuevas de Forever y las de Merchant's Favor (WowFDependencias, generado por herramientas/generar-dependencias.mjs).
-- Todo se recalcula EN VIVO con TUS profesiones y rangos, tu nivel y tu faccion. Precio solo si es real (WowF.precioSubasta); si no hay, no se muestra.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local TOPE_NIVEL = 30      -- tope de nivel de la beta: lo que pide mas rango del que se alcanza con el tope no tiene compradores todavia
local MAS_RANGO = 50       -- "Proximas al subir": hasta este rango por encima del tuyo
local MAX_VENDE, MAX_PROX, MAX_COMPRA = 6, 3, 6
local NOMBRES = { [171] = "Alchemy", [164] = "Blacksmithing", [165] = "Leatherworking", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting",
  [186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [129] = "First Aid", [185] = "Cooking", [356] = "Fishing" }

local function D() return WowFDependencias end
local function nombreProf(id) return NOMBRES[id] or (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function miLado() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and "H" or (f == "Alliance" and "A" or nil) end
local function nivelParaRango(r)
  for _, c in ipairs((WowFDatos and WowFDatos.caps) or {}) do if r <= c[2] then return c[1] end end
  return 35
end
-- Rango maximo que se alcanza con el tope de nivel de la beta (Expert 225 con nivel 20-34)
-- 9-oct: el nivel de WowFDatos.caps es de Classic; nivelParaRango y topeHabilidad solo filtran/ordenan por dentro. NUNCA se muestra al jugador.
local function topeHabilidad()
  local t = 75
  for _, c in ipairs((WowFDatos and WowFDatos.caps) or {}) do if c[1] <= TOPE_NIVEL then t = math.max(t, c[2]) end end
  return t
end
local function ladoVale(lados, lado) return not lado or not lados or lados:find(lado, 1, true) ~= nil end
local function precio(id)
  if not WowF.precioSubasta then return nil end
  local link
  if GetItemInfo then local ok, _, l = pcall(GetItemInfo, id); if ok then link = l end end
  local ok, p, fuente, edad = pcall(WowF.precioSubasta, link or ("item:" .. id), id)
  if ok and type(p) == "number" and p > 0 then return p, fuente, edad end
  return nil
end
local function dinero(c) if WowF.avisoBotinDinero then return WowF.avisoBotinDinero(c) end return tostring(c) .. "c" end
local function textoPrecio(id)
  local p, fuente, edad = precio(id)
  if not p then return nil end
  return BLANCO .. L("Se vende a ", "Sells for ") .. dinero(p) .. GRIS .. " (" .. (fuente == "visto" and L("lo viste", "you saw it") or tostring(fuente)) .. (edad and (", " .. edad) or "") .. ")|r"
end
-- "Tailoring (12), Leatherworking (3)" con las profesiones que mas lo piden primero
local function listaProfs(t, max)
  local l = {}
  for p, n in pairs(t) do table.insert(l, { p = p, n = n }) end
  table.sort(l, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.p < b.p end)
  local partes = {}
  for i = 1, math.min(max or 3, #l) do table.insert(partes, nombreProf(l[i].p) .. " (" .. l[i].n .. ")") end
  if #l > (max or 3) then table.insert(partes, L("y " .. (#l - (max or 3)) .. " mas", "and " .. (#l - (max or 3)) .. " more")) end
  return table.concat(partes, ", ")
end

-- Tus profesiones: { [id] = rango }. WowF.depProfesiones permite a las pruebas forzarlas.
local function misProfesiones()
  if WowF.depProfesiones then return WowF.depProfesiones() end
  local r = {}
  if WowF.profesiones then
    local ok, lista = pcall(WowF.profesiones)
    if ok and type(lista) == "table" then for _, p in ipairs(lista) do if p.id then r[p.id] = tonumber(p.rango) or 0 end end end
  end
  return r
end

local cache, claveCache
-- Calculo en vivo: { vende = { ... }, compra = { ... }, nada = bool }
function WowF.dependencias()
  local d = D()
  if not d or not d.mat or not d.rec then return { sinDatos = true, vende = {}, compra = {} } end
  local mias, N, lado = misProfesiones(), nivelPj(), miLado()
  local partes = { N, lado or "-" }
  for id, r in pairs(mias) do table.insert(partes, id .. "=" .. r) end
  table.sort(partes, function(a, b) return tostring(a) < tostring(b) end)
  local clave = table.concat(partes, "|")
  if cache and claveCache == clave then return cache end
  local tope = topeHabilidad()

  -- Demanda de cada material: recetas de profesiones que NO tienes, de tu faccion y con rango alcanzable en la beta
  local pide = {} -- item -> { total, porProf = { [prof] = n } }
  for _, r in ipairs(d.rec) do
    local prof, rango, lados, mats = r[1], r[2], r[3], r[8]
    if not mias[prof] and rango <= tope and ladoVale(lados, lado) then
      for i = 1, #mats, 2 do
        local it = mats[i]
        local e = pide[it] or { total = 0, porProf = {} }
        e.total = e.total + 1
        e.porProf[prof] = (e.porProf[prof] or 0) + 1
        pide[it] = e
      end
    end
  end

  -- VENDE: lo que saca una profesion tuya y piden otras
  local ya, prox = {}, {}
  for it, m in pairs(d.mat) do
    local dem, caja = pide[it], d.caja and d.caja[it]
    local cajas = caja and caja[1] or 0
    if (dem and dem.total > 0) or cajas > 0 then
      local mejor
      for _, pr in ipairs(m[3] or {}) do
        local q, r, conf = pr[1], pr[2], pr[3]
        local mio = mias[q]
        if mio and (not mejor or r < mejor.rango) then
          -- las recetas que pide tu MISMA profesion no cuentan como "otra profesion"
          local total, porProf = 0, {}
          if dem then for p, n in pairs(dem.porProf) do if p ~= q then porProf[p] = n; total = total + n end end end
          if total > 0 or cajas > 0 then
            mejor = { id = it, nombre = m[1], q = m[2], prof = q, rango = r, conf = conf, mio = mio, total = total, porProf = porProf, cajas = cajas, maxCaja = caja and caja[2] or 0 }
          end
        end
      end
      if mejor then
        if mejor.rango <= mejor.mio then table.insert(ya, mejor)
        elseif mejor.rango <= math.min(mejor.mio + MAS_RANGO, tope) then mejor.nivelDesbloqueo = nivelParaRango(mejor.rango); table.insert(prox, mejor) end
      end
    end
  end
  local function orden(a, b)
    local va, vb = a.total + a.cajas * 2, b.total + b.cajas * 2
    if va ~= vb then return va > vb end
    if a.rango ~= b.rango then return a.rango > b.rango end
    return a.id < b.id
  end
  table.sort(ya, orden)
  table.sort(prox, function(a, b) if a.rango ~= b.rango then return a.rango < b.rango end return orden(a, b) end)

  -- COMPRA: lo que piden TUS recetas nuevas y de Merchant's Favor y no sacas con ninguna profesion tuya
  local porItem, compra = {}, {}
  for _, r in ipairs(d.rec) do
    local prof, rango, lados, fuente, obj, nombre, q, mats = r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
    local mio = mias[prof]
    if mio and rango <= math.min(mio + MAS_RANGO, tope) and ladoVale(lados, lado) then
      for i = 1, #mats, 2 do
        local it, cant = mats[i], mats[i + 1]
        local m = d.mat[it]
        if m then
          local otras, tengoYo = {}, false
          for _, pr in ipairs(m[3] or {}) do
            if pr[1] ~= prof then
              if mias[pr[1]] then tengoYo = true end
              table.insert(otras, pr)
            end
          end
          if not tengoYo then
            local e = porItem[it]
            if not e then
              e = { id = it, nombre = m[1], q = m[2], otras = otras, recetas = 0, ya = false, ejemplo = nil }
              porItem[it] = e; table.insert(compra, e)
            end
            e.recetas = e.recetas + 1
            local esYa = rango <= mio
            if esYa then e.ya = true end
            -- ejemplo: la que ya puedes y de rango mas alto (la mas util), si no, la proxima mas cercana
            local ej = e.ejemplo
            if not ej or (esYa and (not ej.ya or rango > ej.rango)) or (not esYa and not ej.ya and rango < ej.rango) then
              e.ejemplo = { nombre = nombre, q = q, rango = rango, prof = prof, ya = esYa, fuente = fuente, obj = obj, cant = cant }
            end
          end
        end
      end
    end
  end
  table.sort(compra, function(a, b)
    if a.ya ~= b.ya then return a.ya end
    if a.recetas ~= b.recetas then return a.recetas > b.recetas end
    return a.id < b.id
  end)

  cache = { vende = ya, prox = prox, compra = compra, mias = mias, nivel = N, tope = tope }
  claveCache = clave
  return cache
end
function WowF.dependenciasLimpiar() cache, claveCache = nil, nil end

-- Texto de quien saca un material ("Mining", "Skinning o Leatherworking"); vacio si no se sabe
local function quienLoSaca(otras)
  local n = {}
  for _, pr in ipairs(otras or {}) do table.insert(n, nombreProf(pr[1])) end
  return table.concat(n, L(" o ", " or "))
end
local function aproximado(otras)
  for _, pr in ipairs(otras or {}) do if pr[3] == 0 then return true end end
  return false
end
local function icono(h, id)
  local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  if h.icono then return h.icono(o and o[3] or "", id) end
  return nil
end
local function color(h, q) return (h.colorCalidad and h.colorCalidad(q or 1)) or BLANCO end

-- Singular y plural: "1 receta" / "3 recetas", "1 Waylaid Crate" / "2 Waylaid Crates"
local function nRec(n) return n == 1 and L("1 receta", "1 recipe") or L(n .. " recetas", n .. " recipes") end
local function nCaja(n) return n == 1 and "1 Waylaid Crate" or (n .. " Waylaid Crates") end
local function piden(n) return n == 1 and L("que lo pide ", "needed by ") or L("que lo piden ", "needed by ") end

local function filaVende(h, e, proxima)
  local lineas = {}
  local prof = nombreProf(e.prof)
  local frase
  if e.total > 0 and e.cajas > 0 then
    frase = L("Tu " .. prof .. " produce " .. e.nombre .. ", " .. piden(e.total + e.cajas) .. nRec(e.total) .. " de " .. listaProfs(e.porProf) .. " y " .. nCaja(e.cajas) .. ": vendelo.",
      "Your " .. prof .. " produces " .. e.nombre .. ", needed by " .. nRec(e.total) .. " from " .. listaProfs(e.porProf) .. " and " .. nCaja(e.cajas) .. ": sell it.")
  elseif e.total > 0 then
    frase = L("Tu " .. prof .. " produce " .. e.nombre .. ", " .. piden(e.total) .. nRec(e.total) .. " de " .. listaProfs(e.porProf) .. ": vendelo.",
      "Your " .. prof .. " produces " .. e.nombre .. ", needed by " .. nRec(e.total) .. " from " .. listaProfs(e.porProf) .. ": sell it.")
  else
    frase = L("Tu " .. prof .. " produce " .. e.nombre .. ", " .. piden(e.cajas) .. nCaja(e.cajas) .. " (hasta " .. e.maxCaja .. " por caja): vendelo.",
      "Your " .. prof .. " produces " .. e.nombre .. ", needed by " .. nCaja(e.cajas) .. " (up to " .. e.maxCaja .. " per crate): sell it.")
  end
  table.insert(lineas, CELESTE .. frase .. "|r")
  if not proxima then
    local tp = textoPrecio(e.id)
    if tp then table.insert(lineas, tp) end
  end
  -- 9-oct (cero datos de Classic): con conf == 0 el rango no tiene fuente de Forever: no se muestra el numero
  local sinRango = e.conf == 0
  if sinRango then
    table.insert(lineas, GRIS .. L("Rango de " .. prof .. " que lo saca: aun no disponible en Forever; se actualizara en proximas actualizaciones.",
      prof .. " skill that makes it: not available in Forever yet; this will be updated in future updates.") .. "|r")
  end
  local cab
  if sinRango then cab = (proxima and NARANJA or GRIS) .. prof .. L(" (rango aun no disponible)", " (skill not available yet)") .. "|r  "
  elseif proxima then cab = NARANJA .. L("rango ", "skill ") .. e.rango .. "|r  " -- 9-oct: sin "(nivel N)": ese nivel es de Classic
  else cab = GRIS .. prof .. " " .. math.max(1, e.rango) .. "  |r" end
  h.item({ texto = Y(cab .. color(h, e.q) .. e.nombre .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = icono(h, e.id), objeto = e.id, sangria = 12, chico = true })
end

local function filaCompra(h, e)
  local ej = e.ejemplo
  local receta = ej.nombre .. ((e.recetas > 1) and ((e.recetas == 2) and L(" y 1 receta mas", " and 1 more recipe") or L(" y " .. (e.recetas - 1) .. " recetas mas", " and " .. (e.recetas - 1) .. " more recipes")) or "")
  local quien = quienLoSaca(e.otras)
  local lineas = {}
  if quien ~= "" then
    table.insert(lineas, CELESTE .. L("Para fabricar " .. receta .. " necesitas " .. e.nombre .. " de " .. quien .. ": compralo o pide a alguien.",
      "To craft " .. receta .. " you need " .. e.nombre .. " from " .. quien .. ": buy it or ask someone.") .. "|r")
  else
    table.insert(lineas, CELESTE .. L("Para fabricar " .. receta .. " necesitas " .. e.nombre .. ": compralo o pide a alguien.",
      "To craft " .. receta .. " you need " .. e.nombre .. ": buy it or ask someone.") .. "|r")
    table.insert(lineas, NARANJA .. L("Aun no esta confirmado de que profesion sale en Forever; se actualizara en proximas actualizaciones.",
      "It is not confirmed yet which profession makes it in Forever; this will be updated in future updates.") .. "|r")
  end
  if not ej.ya then
    table.insert(lineas, GRIS .. L("Esa receta se desbloquea con " .. nombreProf(ej.prof) .. " " .. ej.rango .. ".",
      "That recipe unlocks at " .. nombreProf(ej.prof) .. " " .. ej.rango .. ".") .. "|r")
  end
  if ej.fuente == "F" then
    table.insert(lineas, GRIS .. L("Receta de Merchant's Favor.", "Merchant's Favor recipe.") .. "|r")
  end
  local tp = textoPrecio(e.id)
  if tp then table.insert(lineas, tp) end
  local cab = ej.ya and (VERDE .. L("lo necesitas  ", "you need it  ") .. "|r") or (NARANJA .. L("proximo  ", "next  ") .. "|r")
  h.item({ texto = Y(cab .. color(h, e.q) .. e.nombre .. "|r" .. GRIS .. "  x" .. ej.cant .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = icono(h, e.id), objeto = e.id, sangria = 12, chico = true })
end

-- Seccion de la pestana Profesiones (objetivo "oro"). Devuelve true si mostro algo.
function WowF.seccionDependencias(h)
  local r = WowF.dependencias()
  if r.sinDatos then return false end
  local alguno = false
  if #r.vende + #r.prox > 0 then
    alguno = true
    h.cab(Y(CELESTE .. L("Vende a otras profesiones", "Sell to other professions") .. "|r"))
    h.nota(Y(GRIS .. L("Materiales que sacas tu y que piden las recetas nuevas de Forever, las de Merchant's Favor y las Waylaid Crates de profesiones que no tienes.",
      "Materials you make that are needed by the new Forever recipes, the Merchant's Favor recipes and the Waylaid Crates of professions you do not have.") .. "|r"))
    if #r.vende > 0 then
      h.item({ texto = Y(VERDE .. L("Ya puedes", "You can now") .. "|r"), sangria = 4, chico = true })
      for i = 1, math.min(MAX_VENDE, #r.vende) do filaVende(h, r.vende[i], false) end
    end
    if #r.prox > 0 then
      h.item({ texto = Y(ORO .. L("Proximas al subir", "Next as you level up") .. "|r" .. GRIS .. L("  (rango en que se desbloquean)", "  (skill that unlocks them)") .. "|r"), sangria = 4, chico = true })
      for i = 1, math.min(MAX_PROX, #r.prox) do filaVende(h, r.prox[i], true) end
    end
  end
  if #r.compra > 0 then
    alguno = true
    h.cab(Y(CELESTE .. L("Lo que necesitas de otras profesiones", "What you need from other professions") .. "|r"))
    h.nota(Y(GRIS .. L("Materiales que piden tus recetas nuevas de Forever y de Merchant's Favor y que no sacas con tus profesiones.",
      "Materials your new Forever and Merchant's Favor recipes need that your professions do not make.") .. "|r"))
    for i = 1, math.min(MAX_COMPRA, #r.compra) do filaCompra(h, r.compra[i]) end
  end
  return alguno
end
