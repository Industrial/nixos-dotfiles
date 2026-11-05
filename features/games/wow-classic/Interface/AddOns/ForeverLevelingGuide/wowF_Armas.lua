-- Forever Leveling Guide: regla de arma por rama (8-oct, Andy: "que recomiende las armas teniendo en cuenta todo... dagas,
-- velocidad... no importa la raza, la clase, horda, alianza"). La MISMA regla que la guia (WF_REGLAS.armas de web/reglas.js),
-- generada en wowF_ArmasDatos.lua (WowFArmas). La usa wowF_Comparar.lua (compararSinQuien) y, por ella, el aviso de botin,
-- el tooltip, la recompensa de mision, el panel de la mazmorra, Equipo y el vendedor.
--   WowF.ajusteArma(o, p, slot) -> { f, porque, malo, aunque, prohibido }
--     f = multiplica la puntuacion del arma (velocidad que no toca = pen; racial de arma = +crit %)
--     porque = por que te va bien; malo = "no te la recomiendo: ..." (si no la elige); aunque = si gana igual
--     motivo = lo que no cumple, sin "no te la recomiendo" (para la BiS de la guia)
--     prohibido = tipo que tu rama no puede llevar en esa mano (Mutilate: Dagger en las dos manos desde el nivel 30)
WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end

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

-- ranura del personaje -> clave de la regla
local CLAVE = { [16] = "mh", [17] = "oh", [18] = "rng" }
local NOMBRE = { mh = { "tu Main Hand", "your Main Hand" }, oh = { "tu Off Hand", "your Off Hand" }, rng = { "tu arma Ranged", "your Ranged weapon" } }

-- Regla de tu rama (nil = tu rama no tiene regla de arma)
function WowF.reglaArma(p)
  if type(p) ~= "table" or not WowFArmas or not WowFArmas.ramas then return nil end
  local clase, rama = p.clase, p.ramaPesos or p.ramaNombre
  if type(clase) ~= "string" or type(rama) ~= "string" then return nil end
  return WowFArmas.ramas[clase .. "|" .. rama]
end

-- Velocidad del tooltip ("Speed 2.60" / "Velocidad 2,60", a la derecha de la linea del daño)
local cacheVel = {}
local function velocidadTooltip(clave)
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) or not clave then return nil end
  if cacheVel[clave] ~= nil then return cacheVel[clave] or nil end
  local datos = llamar(C_TooltipInfo.GetHyperlink, clave)
  if type(datos) ~= "table" or type(datos.lines) ~= "table" then return nil end
  for _, ln in ipairs(datos.lines) do
    local tx = type(ln) == "table" and ln.rightText or nil
    if type(tx) == "string" and not (issecretvalue and issecretvalue(tx)) then
      local v = tx:match("^%D*(%d+[%.,]%d%d)%s*$")
      if v then v = tonumber((v:gsub(",", "."))); cacheVel[clave] = v or false; return v end
    end
  end
  cacheVel[clave] = false
  return nil
end

-- Subclase y velocidad de un arma: primero los datos de Forever (por id), si no, el cliente. nil = no es arma o no se sabe.
function WowF.datosArma(o)
  if type(o) ~= "table" then return nil end
  local id = tonumber(o.id or (type(o.link) == "string" and o.link:match("item:(%d+)")) or "")
  local d = id and WowFArmas and WowFArmas.vel and WowFArmas.vel[id]
  if d then return d[1], d[2] end
  local sub = WowF.subclaseArma and WowF.subclaseArma(o) or nil
  if sub == nil then return nil end
  return sub, velocidadTooltip(o.link or ("item:" .. id))
end

local function nivelJugador() return numero(llamar(UnitLevel, "player")) or 1 end
local function razaJugador()
  if type(UnitRace) ~= "function" then return nil end
  local ok, _, _, id = pcall(UnitRace, "player")
  if not ok or (issecretvalue and issecretvalue(id)) then return nil end
  return tonumber(id)
end
local function velTexto(v) return (string.format("%.2f", v):gsub("0$", "")) end

function WowF.ajusteArma(o, p, slot)
  local r = { f = 1, porque = "", malo = "", aunque = "" }
  local clave = CLAVE[slot or 0]
  if not clave then return r end
  local sub, vel = WowF.datosArma(o)
  if sub == nil then return r end
  local regla = WowF.reglaArma(p)
  local rr = regla and regla[clave]
  local partes = {}
  if rr and rr.tipos and nivelJugador() >= (rr.tiposDesde or 0) then
    local vale = false
    for _, t in ipairs(rr.tipos) do if t == sub then vale = true end end
    if not vale then
      r.prohibido = true
      r.motivo = L(rr.es or "", rr.en or "")
      r.malo = L("no te la recomiendo: " .. (rr.es or ""), "not recommended: " .. (rr.en or ""))
      return r
    end
    table.insert(partes, L(rr.es or "", rr.en or ""))
  end
  if rr and rr.vel and vel and not rr.conf then
    -- 9-oct (regla de Andy: cero datos de Classic): sin fuente de Forever no se penaliza ni se desaconseja el arma por su velocidad
    local n = NOMBRE[clave]
    table.insert(partes, L(n[1] .. ": velocidad ideal aún sin dato de Forever (se actualizará en próximas actualizaciones)",
      n[2] .. ": ideal speed not available in Forever yet (it will be updated in future updates)"))
  elseif rr and rr.vel and vel then
    local lenta = rr.vel == "lenta"
    local ok = lenta and vel >= rr.umbral - 0.000001 or (not lenta and vel <= rr.umbral + 0.000001)
    if ok then
      table.insert(partes, L(rr.es or "", rr.en or ""))
    else
      r.f = r.f * (rr.pen or 1)
      local n = NOMBRE[clave]
      local quiere = L(n[1] .. " quiere " .. (lenta and ("lenta (" .. rr.umbral .. " o más)") or ("rápida (" .. rr.umbral .. " o menos)")),
        n[2] .. " wants " .. (lenta and ("a slow one (" .. rr.umbral .. " or slower)") or ("a fast one (" .. rr.umbral .. " or faster)")))
      local es = lenta and L("rápida", "fast") or L("lenta", "slow")
      r.motivo = L("es " .. es .. " (" .. velTexto(vel) .. ") y " .. quiere, "it is " .. es .. " (" .. velTexto(vel) .. ") and " .. quiere)
      r.malo = L("no te la recomiendo: es " .. es .. " (" .. velTexto(vel) .. ") y " .. quiere,
        "not recommended: it is " .. es .. " (" .. velTexto(vel) .. ") and " .. quiere)
      r.aunque = L("aunque es " .. es .. " (" .. velTexto(vel) .. ") y " .. quiere .. ", suma tanto más que sigue siendo mejor",
        "although it is " .. es .. " (" .. velTexto(vel) .. ") and " .. quiere .. ", it adds so much more that it is still better")
    end
  end
  local rc = WowFArmas and WowFArmas.raciales and WowFArmas.raciales[razaJugador() or 0]
  -- el racial (+crit cuerpo a cuerpo) solo cuenta en ramas que pegan con el arma (peso de DPS de 2 o mas; no sanadores ni lanzadores)
  if rc and p and p.pesos and (p.pesos.dps or 0) >= 2 then
    for _, s in ipairs(rc.subs or {}) do
      if s == sub then r.f = r.f * (1 + (rc.crit or 0) / 100); table.insert(partes, L(rc.es or "", rc.en or "")) end
    end
  end
  r.porque = table.concat(partes, "; ")
  return r
end

-- Nota de la rama (Feral: el DPS del arma cuenta; Subtlety: la BiS es una Sword). nil = nada que decir.
function WowF.notaArma(p)
  local regla = WowF.reglaArma(p)
  if not regla or not regla.nota then return nil end
  return L(regla.nota.es, regla.nota.en)
end
