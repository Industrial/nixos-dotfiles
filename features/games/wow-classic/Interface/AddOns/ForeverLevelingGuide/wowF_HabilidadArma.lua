-- Forever Leveling Guide: habilidad del arma que llevas (5-oct-2026).
-- Una vez por nivel, discreto (una linea en el chat): si la habilidad del arma que llevas en la mano (Swords, Maces...) esta muy
-- por debajo del maximo que da el propio juego (GetSkillLineInfo) a tu nivel, lo dice. 9-oct (cero Classic): sin ese maximo no avisa. Con la habilidad
-- baja fallas mas golpes.
-- Dice tambien que tipo de arma usa tu rama segun el plan (el arma recomendada para tu nivel, de wowF_Datos.lua).
-- Si tu rama usa un arma que aun no sabes usar, dice donde aprenderla: los Weapon Master de TU faccion (Wowhead /forever,
-- herramientas/descargar-maestros-armas.mjs). Wowhead /forever no dice que arma enseña cada uno, asi que eso no se afirma.
-- Lee la habilidad con GetSkillLineInfo; si el cliente no la tiene, se apaga sola sin errores (y /wowf habilidadarma lo dice).
-- /wowf habilidadarma on|off (/wowf weaponskill on|off) y casilla en Ajustes. Encendido por defecto.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, NARANJA, GRIS, BLANCO = "|cff1eff00", "|cffff8000", "|cff9d9d9d", "|cffffffff"
local FALTA_MINIMA = 25 -- unos 5 niveles de retraso

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
local function marcar(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end

function WowF.habilidadArmaActiva() return db().habilidadArma ~= false end
function WowF.habilidadArmaDisponible() return type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" end

-- Subclase de arma (GetItemInfoInstant) -> nombre de la habilidad en ingles (como en el cliente) y en espanol (cliente esES/esMX)
local HABILIDAD = {
  [0] = { "Axes", "Hachas" }, [1] = { "Two-Handed Axes", "Hachas de dos manos" }, [2] = { "Bows", "Arcos" }, [3] = { "Guns", "Armas de fuego" },
  [4] = { "Maces", "Mazas" }, [5] = { "Two-Handed Maces", "Mazas de dos manos" }, [6] = { "Polearms", "Armas de asta" },
  [7] = { "Swords", "Espadas" }, [8] = { "Two-Handed Swords", "Espadas de dos manos" }, [10] = { "Staves", "Bastones" },
  [13] = { "Fist Weapons", "Armas de puño" }, [15] = { "Daggers", "Dagas" }, [16] = { "Thrown", "Armas arrojadizas" },
  [18] = { "Crossbows", "Ballestas" }, [19] = { "Wands", "Varitas" },
}
WowF.HABILIDAD_ARMA = HABILIDAD

local function subclaseDe(itemOLink)
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if type(f) ~= "function" or itemOLink == nil then return nil end
  local ok, _, _, _, _, _, clase, sub = pcall(f, itemOLink)
  if not ok or numero(clase) ~= 2 then return nil end
  return numero(sub)
end

-- Weapon Master segun Wowhead /forever (2026-10-05, herramientas/descargar-maestros-armas.mjs): { nombre, uiMap, x, y, faccion, zona, npcId }
-- 9-oct: posiciones de Wowhead /forever (fuente/wowhead/npc-entrenadores.json). Woo Ping (11867) trae 57,57.4 y otra en 63.8,69:
-- se deja la primera. x/y solo informan: nada pone alfiler con esta tabla (el aviso dice "de tu faccion", sin ruta).
local MAESTROS = {
  { "Hanashi", 1454, 81.4, 19.4, "H", "Orgrimmar", 2704 },
  { "Buliwyf Stonehand", 1455, 61.4, 89.2, "A", "Ironforge", 11865 },
  { "Ilyenia Moonfire", 1457, 57.2, 45.4, "A", "Darnassus", 11866 },
  { "Woo Ping", 1453, 57, 57.4, "A", "Stormwind City", 11867 },
  { "Sayoc", 1454, 81.4, 19.4, "H", "Orgrimmar", 11868 },
  { "Ansekhwa", 1456, 40.4, 62.4, "H", "Thunder Bluff", 11869 },
  { "Archibald", 1458, 56.4, 33.2, "H", "Undercity", 11870 },
  { "Bixi Wobblebonk", 1455, 61.4, 88.4, "A", "Ironforge", 13084 },
}
WowF.MAESTROS_ARMAS = MAESTROS
-- Los de tu faccion (o neutrales), agrupados por ciudad: "Woo Ping (Stormwind City), Buliwyf Stonehand y Bixi Wobblebonk (Ironforge)"
function WowF.maestrosDeArmas()
  local ok, fac = pcall(UnitFactionGroup, "player")
  fac = ok and texto(fac)
  local mia = (fac == "Horde") and "H" or (fac == "Alliance") and "A" or nil
  if not mia then return nil end
  local orden, por = {}, {}
  for _, m in ipairs(MAESTROS) do
    if m[5] == mia or m[5] == "N" then
      if not por[m[6]] then por[m[6]] = {}; orden[#orden + 1] = m[6] end
      table.insert(por[m[6]], m[1])
    end
  end
  if #orden == 0 then return nil end
  local partes = {}
  for _, z in ipairs(orden) do
    local n = por[z]
    local nombres = (#n > 1) and (table.concat(n, ", ", 1, #n - 1) .. L(" y ", " and ") .. n[#n]) or n[1]
    partes[#partes + 1] = nombres .. " (" .. z .. ")"
  end
  return table.concat(partes, ", "), mia
end

-- La habilidad (rango y maximo) por su nombre en la ventana de habilidades.
-- Devuelve rango, maximo, nombre; o nil y completa (true = se leyo toda la lista sin cabeceras plegadas: si no esta, no la sabes)
-- 5-oct (revision): "completa" exige ademas reconocer en la lista al menos UNA habilidad de arma (ingles o espanol). Con el
-- cliente en otro idioma (aleman, frances...) no se reconoce ninguna y no se puede afirmar que no sabes usar un arma.
local NOMBRES_ARMA = {}
for _, h in pairs(HABILIDAD) do NOMBRES_ARMA[h[1]] = true; NOMBRES_ARMA[h[2]] = true end
local function leerHabilidad(nombres)
  if not WowF.habilidadArmaDisponible() then return nil, false end
  local n = numero(llamar(GetNumSkillLines)) or 0
  local completa = n > 0
  local reconocidas = 0
  for i = 1, n do
    local ok, nombre, cabecera, abierta, rango, _, _, maximo = pcall(GetSkillLineInfo, i)
    if not ok then completa = false end
    nombre = ok and texto(nombre)
    if ok and cabecera and abierta == false then completa = false end
    if not nombre then completa = false
    elseif not cabecera then
      if NOMBRES_ARMA[nombre] then reconocidas = reconocidas + 1 end
      for _, x in ipairs(nombres) do
        if nombre == x then return numero(rango), numero(maximo), nombre end
      end
    end
  end
  return nil, completa and reconocidas > 0
end

-- El tipo de arma que usa tu rama segun el plan (el arma recomendada a tu nivel). Texto o nil.
function WowF.armaDeLaRama(nivel)
  if not WowF.armarPlan then return nil end
  local ok, p = pcall(WowF.armarPlan)
  if not ok or type(p) ~= "table" or type(p.mejores) ~= "table" then return nil end
  for _, m in ipairs(p.mejores) do
    if type(m.ranuras) == "table" and m.ranuras[1] == 16 then
      local lista = m[p.faccion or ""] or m.Horda or m.Alianza
      local elegido
      for _, e in ipairs(lista or {}) do if (e[1] or 0) <= nivel and e[2] then elegido = e[2] end end
      local sub = elegido and subclaseDe(elegido)
      local h = sub and HABILIDAD[sub]
      if h then return h[1], m.nombre, p.ramaNombre, h end
      return nil, m.nombre, p.ramaNombre
    end
  end
  return nil
end

-- La comprobacion. Devuelve el texto del aviso o nil (nada que decir / no se puede leer).
function WowF.revisarHabilidadArma()
  if not WowF.habilidadArmaActiva() or not WowF.habilidadArmaDisponible() then return nil end
  local nivel = numero(llamar(UnitLevel, "player"))
  if not nivel then return nil end
  local partes = {}
  -- (1) El arma que llevas: habilidad frente al maximo que da el CLIENTE (GetSkillLineInfo). 9-oct (regla de Andy: CERO datos
  -- de Classic): sin maximo del cliente no se avisa (antes se suponia nivel x 5).
  local link = texto(llamar(GetInventoryItemLink, "player", 16))
  local sub = link and subclaseDe(link)
  local h = sub and HABILIDAD[sub]
  local arma, ranura, rama, hRama = WowF.armaDeLaRama(nivel)
  -- 5-oct (revision): la rama y la ranura vienen de los datos (en espanol o en ingles): pasan por WowF.T antes de unirse
  -- al texto, porque al final todo se marca como ya traducido
  if WowF.T then
    if type(rama) == "string" then rama = WowF.T(rama) end
    if type(ranura) == "string" then ranura = WowF.T(ranura) end
  end
  if h then
    local rango, maximo = leerHabilidad({ h[1], h[2] })
    if rango then
      local tope = tonumber(maximo)
      if tope and tope > 0 and tope - rango >= FALTA_MINIMA then
        local t = NARANJA .. L("Habilidad de arma baja: ", "Low weapon skill: ") .. "|r" .. BLANCO .. h[1] .. " " .. rango .. "/" .. tope .. "|r" ..
          L(" (con la habilidad baja fallas mas golpes; sube usando esa arma).", " (with low skill you miss more; it goes up as you use that weapon).")
        if arma and arma ~= h[1] then
          t = t .. " " .. GRIS .. L("Tu rama" .. (rama and (" (" .. rama .. ")") or "") .. " usa: ", "Your spec" .. (rama and (" (" .. rama .. ")") or "") .. " uses: ") ..
            arma .. (ranura and (" (" .. ranura .. ")") or "") .. ".|r"
        end
        partes[#partes + 1] = t
      end
    end
  end
  -- (2) El arma de tu rama: si la lista de habilidades se leyo entera y no esta, aun no la sabes usar -> Weapon Master de tu faccion
  if hRama and not (h and h[1] == hRama[1]) then
    local rango, completa = leerHabilidad({ hRama[1], hRama[2] })
    if not rango and completa == true then
      local donde = WowF.maestrosDeArmas()
      local t = NARANJA .. L("Aun no sabes usar ", "You cannot use ") .. hRama[1] .. "|r" ..
        L(", el arma de tu rama" .. (rama and (" (" .. rama .. ")") or "") .. ".", (rama and (" yet, your spec's weapon (" .. rama .. ").") or " yet, your spec's weapon."))
      if donde then
        t = t .. " " .. L("Se aprende con un Weapon Master de tu faccion: ", "Learn it from a Weapon Master of your faction: ") .. donde ..
          ". " .. GRIS .. L("Preguntale cual la enseña.", "Ask which one teaches it.") .. "|r"
      end
      partes[#partes + 1] = t
    end
  end
  if #partes == 0 then return nil end
  return marcar(table.concat(partes, " "))
end

-- Una vez por nivel y personaje
local function clavePj()
  local n = texto(llamar(UnitName, "player")) or "?"
  local r = texto(llamar(GetRealmName)) or "?"
  return n .. "-" .. r
end
function WowF.avisoHabilidadArma(forzar)
  local nivel = numero(llamar(UnitLevel, "player"))
  if not nivel then return nil end
  local t = db()
  if type(t.habArma) ~= "table" then t.habArma = {} end
  local k = clavePj()
  if not forzar and t.habArma[k] == nivel then return nil end
  local ok, aviso = pcall(WowF.revisarHabilidadArma)
  if not ok or not aviso then return nil end
  t.habArma[k] = nivel
  print(PREFIJO .. aviso)
  return aviso
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  -- Al subir, UnitLevel puede tardar un instante en cambiar: se mira un poco despues
  if C_Timer and C_Timer.After then C_Timer.After(evento == "PLAYER_LEVEL_UP" and 3 or 8, function() pcall(WowF.avisoHabilidadArma) end)
  else pcall(WowF.avisoHabilidadArma) end
end)

-- Casilla en Ajustes (wowF_Opciones.lua)
if WowF.registrarCasillaOpciones then WowF.registrarCasillaOpciones("habilidadArma", function() return L("Avisarme si la habilidad de mi arma va baja", "Alert me when my weapon skill is low") end) end

-- ===================== /wowf habilidadarma =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "habilidadarma" or orden == "weaponskill" then
    local t = db()
    if resto == "off" or resto == "no" then t.habilidadArma = false elseif resto == "on" or resto == "si" then t.habilidadArma = true
    else t.habilidadArma = not WowF.habilidadArmaActiva() end
    local extra = ""
    if not WowF.habilidadArmaDisponible() then extra = GRIS .. L(" (este cliente no deja leer las habilidades de arma: no hara nada)", " (this client does not let addons read weapon skills: it will do nothing)") .. "|r" end
    print(PREFIJO .. L("aviso de habilidad de arma ", "weapon skill alert ") .. (WowF.habilidadArmaActiva() and (VERDE .. L("ENCENDIDO", "ON")) or (GRIS .. L("APAGADO", "OFF"))) .. "|r" ..
      extra .. L(". /wowf habilidadarma on|off", ". /wowf weaponskill on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
