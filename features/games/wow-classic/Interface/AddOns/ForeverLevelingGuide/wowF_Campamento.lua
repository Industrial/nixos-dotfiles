-- wowF Campamento: los objetos de campamento de las profesiones de WoW Forever (8-oct).
--   * Pestana Profesiones del Libro: para TUS profesiones (y las que te pone el plan), "Ya puedes" / "Proximo al subir" segun TU rango,
--     para que sirve cada objeto con el valor a TU nivel, como se aprende (entrenador o Blueprint: donde cae) y el aviso de que los
--     rangos (20 / 140 / 300) vienen de la beta y no estan confirmados.
--   * Ficha de la mazmorra (Libro y panel): los Blueprints que caen dentro, solo de tus profesiones o las del plan.
--   * Aviso de botin: aviso verde si te cae un Blueprint de tu profesion.
-- Datos: WowFCampamento (wowF_Campamento_Datos.lua, generado por herramientas/generar-campamento.mjs desde las tablas del cliente
-- de la beta y Wowhead /forever). Nada de la otra faccion (Faction Banner). Lo que no se sabe: "sin confirmar, se actualizara".

WowF = WowF or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA, MORADO = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cffcc88ff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local function D() return WowFCampamento end
local function lado()
  local ok, f = pcall(UnitFactionGroup, "player")
  if ok and f == "Horde" then return "H" elseif ok and f == "Alliance" then return "A" end
  return nil
end
local function nivelPj() local ok, n = pcall(UnitLevel, "player"); n = ok and tonumber(n) or nil; return n or 1 end
local function nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
local function sinConfirmar() return L("sin confirmar, se actualizara en proximas actualizaciones", "unconfirmed, it will be updated in future updates") end
local function sabida(spell)
  if not IsPlayerSpell or not spell then return false end
  local ok, si = pcall(IsPlayerSpell, spell)
  return ok and si == true
end

-- Filas de WowFCampamento.objetos como tablas con nombre
local filas
local function objetos()
  if filas then return filas end
  filas = {}
  local d = D()
  for _, r in ipairs((d and d.objetos) or {}) do
    table.insert(filas, { receta = r[1], n = r[2], prof = r[3], tier = r[4], objeto = r[5], rango = r[6], fac = r[7], bp = r[8], coste = r[9],
      s1 = r[10], s2 = r[11], sust = r[12], base = r[13], fogata = r[14], cad = r[15] or {}, es = r[16], en = r[17] })
  end
  return filas
end
local function deMiLado(o) return o.fac == "" or o.fac == lado() end
local function porNombre(n)
  for _, o in ipairs(objetos()) do if o.n == n and deMiLado(o) then return o end end
  return nil
end

-- Valor de una cadena de la descripcion a un nivel: "<" = el del primer limite que tu nivel no alcanza; ">" = el del primero que pasas
local function valorCadena(c, N)
  local op, t, def = c[1], c[2] or {}, c[3] or 0
  for _, x in ipairs(t) do
    if op == "<" and N < x[1] then return x[2] end
    if op == ">" and N > x[1] then return x[2] end
  end
  return def
end
WowF.campamentoValor = valorCadena

-- Para que sirve, con los numeros de TU nivel
local function textoObjeto(o, N, sinBase)
  local s = L(o.es or "", o.en or "")
  s = s:gsub("{s1}", tostring(o.s1 or 0)):gsub("{s2}", tostring(o.s2 or 0))
  for i = 1, 3 do
    local c = o.cad[i]
    s = s:gsub("{" .. i .. "}", c and tostring(valorCadena(c, N)) or "?")
  end
  -- Lo que a tu nivel aun da 0 no se nombra (Enchanted Lute: las resistencias llegan al nivel 30)
  local n1, n2
  s, n1 = s:gsub(" y %+0 a todas las resistencias", "")
  s, n2 = s:gsub(" and %+0 to all resistances", "")
  if n1 + n2 > 0 then s = s:gsub("Armor, %+", L("Armor y +", "Armor and +"), 1) end
  if not sinBase and o.base ~= "" then
    local b = porNombre(o.base)
    if b then s = s .. " " .. GRIS .. "(" .. b.n .. ": " .. textoObjeto(b, N, true) .. ")|r" end
  end
  return s
end
WowF.campamentoTexto = function(o, N) return textoObjeto(o, N or nivelPj()) end

-- Probabilidad de un Blueprint (veces / de cuantas) en texto
local function pct(count, outof)
  if not count or not outof or outof <= 0 then return nil end
  local p = count * 100 / outof
  local s = (p < 0.1) and "<0.1" or string.format("%.1f", p)
  if outof < 500 then s = s .. " %" .. L(", con pocos datos todavía", ", based on little data so far") else s = s .. " %" end
  return s
end

-- Donde cae un Blueprint, en una linea (solo mazmorras de tu faccion o de las dos)
local function dondeCae(bpId)
  local d = D(); local b = d and d.bp and d.bp[bpId]
  if not b then return nil end
  local partes = {}
  local l = lado()
  for _, x in ipairs(b[7] or {}) do
    local fac = x[5] or 0
    if fac == 0 or (fac == 1 and l == "H") or (fac == 2 and l == "A") then
      local p = pct(x[6], x[7])
      table.insert(partes, x[2] .. L(" en ", " in ") .. x[4] .. (p and (" (~" .. p .. ")") or ""))
    end
  end
  if #partes == 0 then return nil end
  return table.concat(partes, L("; o ", "; or "))
end
WowF.campamentoDondeCae = dondeCae

-- Tus profesiones (con rango) + las que te pone el plan (rango 0 si aun no la tienes)
local function misProfesiones()
  local res, visto = {}, {}
  local ok, lista = pcall(function() return WowF.profesiones and WowF.profesiones() end)
  for _, p in ipairs((ok and lista) or {}) do
    if not visto[p.id] then visto[p.id] = true; table.insert(res, { id = p.id, rango = tonumber(p.rango) or 0, tiene = true }) end
  end
  local ok2, plan = pcall(function() return WowF.armarPlan and WowF.armarPlan() end)
  for _, id in ipairs((ok2 and type(plan) == "table" and plan.ids) or {}) do
    if not visto[id] then visto[id] = true; table.insert(res, { id = id, rango = 0, tiene = false }) end
  end
  return res
end
WowF.campamentoProfesiones = misProfesiones
local function esMia(prof)
  for _, p in ipairs(misProfesiones()) do if p.id == prof then return p end end
  return nil
end

-- Lo de una profesion a tu rango: { ya = {objetos}, prox = {objetos} } (orden por rango)
function WowF.campamentoDeProfesion(prof, rango)
  local ya, prox = {}, {}
  for _, o in ipairs(objetos()) do
    if o.prof == prof and deMiLado(o) then
      if (rango or 0) >= (o.rango or 0) then table.insert(ya, o) else table.insert(prox, o) end
    end
  end
  table.sort(ya, function(a, b) return a.rango < b.rango end)
  table.sort(prox, function(a, b) return a.rango < b.rango end)
  return { ya = ya, prox = prox }
end

-- Como se aprende, en una linea
local function comoSeAprende(o)
  if o.bp == 0 then
    -- 15-oct: oro, plata y cobre (antes 1 oro salia como "100 de plata")
    local c = math.floor(o.coste or 0)
    local partes = {}
    if c >= 10000 then table.insert(partes, math.floor(c / 10000) .. L(" de oro", " gold")) end
    if math.floor(c / 100) % 100 > 0 then table.insert(partes, (math.floor(c / 100) % 100) .. L(" de plata", " silver")) end
    if c % 100 > 0 then table.insert(partes, (c % 100) .. L(" de cobre", " copper")) end
    local coste = c > 0 and (" (" .. table.concat(partes, " ") .. ")") or ""
    return L("Se aprende con el entrenador de ", "Learned from the ") .. nombreProf(o.prof) .. L("", " trainer") .. coste .. "."
  end
  local d = D(); local b = d and d.bp and d.bp[o.bp]
  local nombre = (b and b[1]) or L("Blueprint", "Blueprint")
  local pide = (b and b[3] and b[3] ~= o.rango) and (L(" (el Blueprint pide rango ", " (the Blueprint requires skill ") .. b[3] .. ")") or ""
  local donde = dondeCae(o.bp)
  if donde then return L("Se aprende con ", "Learned from ") .. nombre .. pide .. L(". Lo suelta: ", ". Dropped by: ") .. donde .. "." end
  return L("Se aprende con ", "Learned from ") .. nombre .. pide .. L(". Donde cae: ", ". Where it drops: ") .. NARANJA .. sinConfirmar() .. "|r."
end
WowF.campamentoComo = comoSeAprende

-- ===================== Pestana Profesiones =====================
function WowF.seccionCampamento(p, h)
  local d = D()
  h.cab(ORO .. L("Campamento: objetos de profesion", "Camp: profession camp items") .. "|r")
  if not d then
    h.nota(GRIS .. L("Faltan los datos del campamento: reinstala el addon.", "Camp data is missing: reinstall the addon.") .. "|r")
    return
  end
  local N = nivelPj()
  h.nota(Y(BLANCO .. L("Pon una fogata (Basic Campfire Kit, de Cooking) y alrededor los objetos de cada profesion. Sientate cerca ",
    "Place a campfire (Basic Campfire Kit, from Cooking) and the profession items around it. Sit nearby for ")
    .. (d.sentado or 60) .. L(" s para recibir sus beneficios. Todos los objetos comparten una espera de ", " sec to get their benefits. All camp items share a cooldown of ")
    .. (WowF.esperaCampamento and WowF.esperaCampamento(d.reutilizacion or 60) or (d.reutilizacion or 60)) .. L(" min", " min") .. (WowF.esperaCampamento and select(2, WowF.esperaCampamento(d.reutilizacion or 60)) or "") .. L(". Cada objeto de Tier 2/3 se pone encima del de Tier 1 y da lo mismo y algo mas.",
      ". Each Tier 2/3 item goes over the Tier 1 one and gives the same and more.") .. "|r"))
  h.nota(Y(NARANJA .. L("Rangos 20 / 140 / 300: vienen de la beta y estan ", "Skill levels 20 / 140 / 300: they come from the beta and are ") .. sinConfirmar() .. ".|r"))
  local mias = misProfesiones()
  local alguna = false
  for _, pr in ipairs(mias) do
    local r = WowF.campamentoDeProfesion(pr.id, pr.rango)
    if #r.ya + #r.prox > 0 then
      alguna = true
      local quien = pr.tiene and (L(" (tu rango: ", " (your skill: ") .. pr.rango .. ")") or L(" (te la pone el plan; aún no la tienes)", " (your plan adds it; you do not have it yet)")
      h.nota(Y(ORO .. nombreProf(pr.id) .. "|r" .. GRIS .. quien .. "|r"))
      if #r.ya > 0 then
        h.nota(Y(VERDE .. L("Ya puedes:", "You can now:") .. "|r"))
        for _, o in ipairs(r.ya) do
          local ya = sabida(o.receta)
          h.item({ texto = Y(VERDE .. o.n .. "|r" .. GRIS .. L(" (Tier ", " (Tier ") .. o.tier .. L(", rango ", ", skill ") .. o.rango .. ")" .. (ya and L(" - ya lo sabes", " - already known") or "") .. "|r"),
            sub = Y(BLANCO .. textoObjeto(o, N) .. "|r\n" .. GRIS .. comoSeAprende(o) .. "|r"),
            icono = h.icono and o.objeto > 0 and h.icono(nil, o.objeto) or nil, objeto = o.objeto > 0 and o.objeto or nil, sangria = 12, chico = true })
        end
      end
      if #r.prox > 0 then
        h.nota(Y(NARANJA .. L("Proximo al subir:", "Next as you level up:") .. "|r"))
        for _, o in ipairs(r.prox) do
          local falta = (o.rango or 0) - (pr.rango or 0)
          h.item({ texto = Y(BLANCO .. o.n .. "|r" .. GRIS .. L(" (Tier ", " (Tier ") .. o.tier .. L(", a rango ", ", at skill ") .. o.rango .. L("; te faltan ", "; ") .. falta .. L(" puntos)", " points to go)") .. "|r"),
            sub = Y(BLANCO .. textoObjeto(o, N) .. "|r\n" .. GRIS .. comoSeAprende(o) .. "|r"),
            icono = h.icono and o.objeto > 0 and h.icono(nil, o.objeto) or nil, objeto = o.objeto > 0 and o.objeto or nil, sangria = 12, chico = true })
        end
      end
    end
  end
  if not alguna then
    h.nota(GRIS .. L("Aun no tienes profesiones: cuando aprendas una, aqui veras sus objetos de campamento.",
      "You have no professions yet: once you learn one, its camp items show up here.") .. "|r")
  end
end

-- ===================== Ficha de la mazmorra =====================
-- Lineas de los Blueprints que caen en la mazmorra (por su nombre `m.n`), solo de tus profesiones o las del plan. {} si no hay.
function WowF.campamentoFicha(nombreMaz)
  local d = D()
  local res = {}
  local lista = d and d.porMazmorra and d.porMazmorra[nombreMaz]
  if not lista then return res end
  for _, id in ipairs(lista) do
    local b = d.bp[id]
    local pr = b and esMia(b[2])
    if pr then
      local jefes = {}
      for _, x in ipairs(b[7] or {}) do
        if x[4] == nombreMaz then
          local p = pct(x[6], x[7])
          table.insert(jefes, x[2] .. (p and (" ~" .. p) or ""))
        end
      end
      local o
      for _, z in ipairs(objetos()) do if z.bp == id then o = z end end
      local ya = o and sabida(o.receta)
      local estado
      if ya then estado = L("ya lo sabes", "already known")
      elseif pr.tiene and pr.rango >= (b[3] or 0) then estado = L("puedes aprenderlo ya", "you can learn it now")
      else estado = L("pide ", "requires ") .. nombreProf(b[2]) .. " " .. (b[3] or "?") end
      table.insert(res, Y(MORADO .. b[1] .. "|r" .. GRIS .. " (" .. nombreProf(b[2]) .. L(", campamento Tier ", ", camp Tier ") .. (b[5] or "?") .. "): "
        .. L("lo suelta ", "dropped by ") .. table.concat(jefes, ", ") .. " · " .. estado .. "|r"))
    end
  end
  return res
end

-- ===================== Aviso de botin =====================
-- Texto verde si el objeto es un Blueprint de tu profesion (o de la del plan); nil si no.
function WowF.campamentoBotin(id, link)
  local d = D()
  local b = id and d and d.bp and d.bp[id]
  if not b then return nil end
  local pr = esMia(b[2])
  if not pr then return nil end
  local nombre = link or b[1]
  local o
  for _, z in ipairs(objetos()) do if z.bp == id then o = z end end
  local para = o and textoObjeto(o, nivelPj()) or ""
  local porque = L("Blueprint de ", "Blueprint for ") .. nombreProf(b[2])
  if o and sabida(o.receta) then
    return VERDE .. L("Blueprint: ", "Blueprint: ") .. "|r" .. nombre .. L(" - ya lo sabes; puedes venderlo.", " - you already know it; you can sell it."), porque
  end
  local que = L(" enseña a hacer ", " teaches ") .. (b[4] ~= "" and b[4] or "?") .. " (" .. L("campamento Tier ", "camp Tier ") .. (b[5] or "?") .. "): " .. para .. " "
  if pr.tiene and pr.rango >= (b[3] or 0) then
    return VERDE .. L("¡Blueprint para ti! ", "Blueprint for you! ") .. "|r" .. nombre .. que .. VERDE .. L("Usalo ya para aprenderlo.", "Use it now to learn it.") .. "|r", porque
  end
  local tengo = pr.tiene and (L(" (tienes ", " (you have ") .. pr.rango .. ")") or L(" (aún no tienes la profesión)", " (you do not have the profession yet)")
  return VERDE .. L("¡Blueprint para ti! ", "Blueprint for you! ") .. "|r" .. nombre .. que .. VERDE .. L("Guardalo: lo aprendes con ", "Keep it: you learn it at ")
    .. nombreProf(b[2]) .. " " .. (b[3] or "?") .. tengo .. ".|r", porque
end
