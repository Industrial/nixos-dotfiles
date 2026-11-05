-- Forever Leveling Guide: compara cada pieza del botin con la que llevas puesta en esa ranura, con los pesos de tu rama
-- (los mismos de la guia). Solo se recomienda si mejora tu puntuacion; o.porque = explicacion corta de por que.
-- 4-oct: dice si la suelta un jefe, la ranura y el nivel que pide; lee las lineas "Equip:" de lo puesto; si algo de lo
-- puesto no se puede leer NO afirma que sea mejor (o.mejora = false).
WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end

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

-- id de estadistica de los datos -> clave de GetItemStats y nombre del juego (en ingles, como en el cliente)
local STAT = {
  [3] = { "ITEM_MOD_AGILITY_SHORT", "Agility" }, [4] = { "ITEM_MOD_STRENGTH_SHORT", "Strength" },
  [5] = { "ITEM_MOD_INTELLECT_SHORT", "Intellect" }, [6] = { "ITEM_MOD_SPIRIT_SHORT", "Spirit" },
  [7] = { "ITEM_MOD_STAMINA_SHORT", "Stamina" }, [12] = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "Defense Rating" },
  [13] = { "ITEM_MOD_DODGE_RATING_SHORT", "Dodge Rating" }, [14] = { "ITEM_MOD_PARRY_RATING_SHORT", "Parry Rating" },
  [15] = { "ITEM_MOD_BLOCK_RATING_SHORT", "Block Rating" }, [31] = { "ITEM_MOD_HIT_RATING_SHORT", "Hit Rating" },
  [32] = { "ITEM_MOD_CRIT_RATING_SHORT", "Critical Strike Rating" }, [36] = { "ITEM_MOD_HASTE_RATING_SHORT", "Haste Rating" },
  [37] = { "ITEM_MOD_EXPERTISE_RATING_SHORT", "Expertise Rating" }, [38] = { "ITEM_MOD_ATTACK_POWER_SHORT", "Attack Power" },
  [39] = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "Ranged Attack Power" }, [40] = { "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "Feral Attack Power" },
  [41] = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "Healing" }, [42] = { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "Spell Damage" },
  [43] = { "ITEM_MOD_MANA_REGENERATION_SHORT", "Mana per 5 sec." }, [44] = { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", "Armor Penetration" },
  [45] = { "ITEM_MOD_SPELL_POWER_SHORT", "Spell Power" }, [47] = { "ITEM_MOD_SPELL_PENETRATION_SHORT", "Spell Penetration" },
  [48] = { "ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value" },
}
local DISTANCIA = { [15] = true, [25] = true, [26] = true }

-- 12-oct (amigo de Andy, Mage Frost: Firestarter "+4 Fire" salia como mejora sobre Charred Wand): el dano de UNA escuela
-- ("Increases damage done by Fire spells") ya no cuenta como Spell Damage general. Va en su propia estadistica (142-147) y
-- solo vale (con el peso de Spell Damage de tu rama) si tu rama lanza hechizos de esa escuela. Escuelas segun la rotacion
-- de cada rama en wowF_Rotacion.lua (guias de WoW Forever); 0.5 = la usa, pero no es su dano principal.
local ESCUELA_ID = { fire = 142, frost = 143, shadow = 144, arcane = 145, nature = 146, holy = 147 }
STAT[142] = { "-", "Fire Damage" }; STAT[143] = { "-", "Frost Damage" }; STAT[144] = { "-", "Shadow Damage" }
STAT[145] = { "-", "Arcane Damage" }; STAT[146] = { "-", "Nature Damage" }; STAT[147] = { "-", "Holy Damage" }
local ESCUELAS = {
  ["MAGE|Frost"] = { [143] = 1 }, ["MAGE|Fire"] = { [142] = 1 }, ["MAGE|Arcane"] = { [145] = 1 },
  ["WARLOCK|Affliction"] = { [144] = 1, [142] = 0.5 }, ["WARLOCK|Destruction"] = { [144] = 1, [142] = 1 },
  ["WARLOCK|Demonology"] = { [144] = 1, [142] = 0.5 },
  ["PRIEST|Shadow"] = { [144] = 1 }, ["PRIEST|Discipline"] = { [147] = 1, [144] = 0.5 }, ["PRIEST|Holy"] = { [147] = 1, [144] = 0.5 },
  ["SHAMAN|Elemental"] = { [146] = 1, [142] = 0.5 }, ["SHAMAN|Enhancement"] = { [146] = 0.5, [142] = 0.5 },
  ["SHAMAN|Restoration"] = { [146] = 0.5, [142] = 0.5 },
  ["DRUID|Balance"] = { [146] = 1, [145] = 0.5 }, ["DRUID|Restoration"] = { [146] = 0.5, [145] = 0.5 },
  ["PALADIN|Holy"] = { [147] = 1 }, ["PALADIN|Protection"] = { [147] = 1 }, ["PALADIN|Retribution"] = { [147] = 1 },
}
WowF.ESCUELAS_RAMA = ESCUELAS
-- Pesos de tu rama + el de cada escuela (nunca se toca la tabla de pesos original)
local conEscuela = setmetatable({}, { __mode = "k" })
local function pesosDe(p)
  local pesos = (p or {}).pesos
  if type(pesos) ~= "table" then return nil end
  local rama = tostring(p.ramaPesos or p.ramaNombre or ""):match("^(%a+)") or ""
  local clave = tostring(p.clase or "") .. "|" .. rama
  local c = conEscuela[pesos]
  if c and c.clave == clave then return c.t end
  local t = setmetatable({}, { __index = pesos })
  local sd = tonumber(pesos[42]) or 0
  for id, f in pairs(ESCUELAS[clave] or {}) do t[id] = sd * f end
  conEscuela[pesos] = { clave = clave, t = t }
  return t
end
WowF.pesosDe = pesosDe

-- inv del objeto -> ranuras del personaje con que se compara (anillos y trinkets: la peor de las dos)
local RANURA = { [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 }, [9] = { 9 },
  [10] = { 10 }, [16] = { 15 }, [11] = { 11, 12 }, [12] = { 13, 14 }, [13] = { 16 }, [21] = { 16 }, [17] = { 16 }, [14] = { 17 },
  [22] = { 17 }, [23] = { 17 }, [15] = { 18 }, [25] = { 18 }, [26] = { 18 }, [28] = { 18 } }

-- Nombre de la ranura del personaje (en ingles, como en el cliente)
local NOMBRE_RANURA = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
  [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged" }

-- Lineas "Equip:" del tooltip (spell power, attack power...): GetItemStats no siempre las trae. Mismos patrones que
-- herramientas/descargar-botin.mjs (EQUIPAR), en minusculas. Una linea "Equip:" que no se entiende = comparacion insegura.
local EQUIP = {
  { "^equip: increases damage and healing done by magical spells and effects by up to (%d+)", 45, 1 },
  { "^equip: increases healing done by spells and effects by up to (%d+)", 41, 1 },
  { "^equip: increases healing done by magical spells and effects by up to (%d+)", 41, 1 },
  { "^equip: increases damage done by spells and effects by up to (%d+)", 42, 1 },
  { "^equip: increases damage done by magical spells and effects by up to (%d+)", 42, 1 },
  { "^equip: improves your chance to get a critical strike with spells by ([%d%.]+)%%", 32, 14 },
  { "^equip: improves your chance to get a critical strike by ([%d%.]+)%%", 32, 14 },
  { "^equip: improves your chance to hit with spells by ([%d%.]+)%%", 31, 10 },
  { "^equip: improves your chance to hit by ([%d%.]+)%%", 31, 10 },
  { "^equip: %+(%d+) attack power", 38, 1 }, { "^equip: increases attack power by (%d+)", 38, 1 },
  { "^equip: %+(%d+) ranged attack power", 39, 1 },
  { "^equip: restores (%d+) mana per 5 sec", 43, 1 },
  { "^equip: restores (%d+) health per 5 sec", 46, 1 },
  { "^equip: increased defense %+(%d+)", 12, 1 },
  { "^equip: increases your chance to dodge an attack by ([%d%.]+)%%", 13, 12 },
  { "^equip: increases your chance to parry an attack by ([%d%.]+)%%", 14, 20 },
  { "^equip: increases your chance to block attacks with a shield by ([%d%.]+)%%", 15, 5 },
  { "^equip: increases the block value of your shield by (%d+)", 48, 1 },
}
local function lineaEquip(texto, st)
  local l = texto:lower()
  local a, b = l:match("^equip: increases healing done by up to (%d+) and damage done by up to (%d+)")
  if a then st[41] = math.max(st[41] or 0, tonumber(a)); st[42] = math.max(st[42] or 0, tonumber(b)); return true end
  -- 12-oct: dano de una sola escuela -> su propia estadistica; si el juego ya lo puso como Spell Damage general, se quita de alli
  local esc, ve = l:match("^equip: increases damage done by (%a+) spells and effects by up to (%d+)")
  if esc and ESCUELA_ID[esc] then
    ve = tonumber(ve)
    local id = ESCUELA_ID[esc]
    st[id] = math.max(st[id] or 0, ve)
    -- 12-oct: tampoco contarla dos veces si el cliente la puso como Spell Power (45)
    if st[42] == ve then st[42] = nil end
    if st[45] == ve then st[45] = nil end
    return true
  end
  for _, e in ipairs(EQUIP) do
    local v = tonumber(l:match(e[1]) or "")
    if v then v = math.floor(v * e[3] + 0.5); st[e[2]] = math.max(st[e[2]] or 0, v); return true end
  end
  return false
end

-- Indice propio por id: si llevas puesta una pieza del botin, se compara con sus datos reales (Wowhead), no con GetItemStats
local conocidas = {}
local function indexar(p)
  for _, lista in pairs((p and p.botin) or {}) do
    for _, o in ipairs(lista) do if o.id and o.st and not conocidas[o.id] then conocidas[o.id] = o end end
  end
end
local function idDe(link) return tonumber(link:match("item:(%d+)") or "") end

-- Estadisticas de lo que llevas en una ranura: nil = vacia; false = no se pudo leer.
-- o.incierto = tiene un efecto "Equip:" que no se pudo leer: no se afirma que lo nuevo sea mejor.
local leidas = {}
local function puesto(ranura)
  if type(GetInventoryItemLink) ~= "function" then return false end
  local ok, link = pcall(GetInventoryItemLink, "player", ranura)
  if not ok or (issecretvalue and issecretvalue(link)) then return false end
  if type(link) ~= "string" or link == "" then return nil end
  if leidas[link] then return leidas[link] end
  local id = idDe(link)
  local o
  -- 7-oct (auditoria): una copia con sufijo aleatorio ("of the Monkey") tiene estadisticas propias que los datos del botin
  -- no traen: entonces se leen del juego (GetItemStats del enlace), no de Wowhead. Sufijo = 7.o campo tras el id.
  local sufijo = link:match("item:%d+:[^:|]*:[^:|]*:[^:|]*:[^:|]*:[^:|]*:([^:|]*)")
  if id and conocidas[id] and (sufijo == nil or sufijo == "" or sufijo == "0") then
    local c = conocidas[id]
    o = { st = {}, ar = c.ar or 0, dps = c.dps or 0, link = link, id = id }
    local l = c.st or {}
    for i = 1, #l - 1, 2 do o.st[l[i]] = (o.st[l[i]] or 0) + l[i + 1] end
  else
    local f = (C_Item and C_Item.GetItemStats) or GetItemStats
    local t = llamar(f, link)
    if type(t) ~= "table" then return false end
    o = { st = {}, ar = 0, dps = 0, link = link, id = id }
    for sid, s in pairs(STAT) do
      local v = numero(t[s[1]]) or numero(t[(s[1]:gsub("_SHORT$", ""))])
      if v and v ~= 0 then o.st[sid] = v end
    end
    o.ar = numero(t.RESISTANCE0_NAME) or 0
    o.dps = numero(t.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) or 0
    -- Lineas "Equip:" del tooltip (solo si el cliente tiene C_TooltipInfo)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
      local datos = llamar(C_TooltipInfo.GetInventoryItem, "player", ranura)
      if type(datos) ~= "table" or type(datos.lines) ~= "table" then
        o.incierto = true
      else
        local prefijo = (type(ITEM_SPELL_TRIGGER_ONEQUIP) == "string" and ITEM_SPELL_TRIGGER_ONEQUIP) or "Equip:"
        for _, ln in ipairs(datos.lines) do
          local tx = type(ln) == "table" and ln.leftText or nil
          if tx ~= nil and issecretvalue and issecretvalue(tx) then o.incierto = true
          elseif type(tx) == "string" and tx:sub(1, #prefijo) == prefijo then
            if not lineaEquip("Equip:" .. tx:sub(#prefijo + 1), o.st) then o.incierto = true end
          end
        end
      end
    end
  end
  leidas[link] = o
  return o
end

-- La Main Hand puesta es de dos manos (entonces no puedes llevar nada en la Off Hand)
local function dosManosPuesta()
  if type(GetInventoryItemLink) ~= "function" then return false end
  local ok, link = pcall(GetInventoryItemLink, "player", 16)
  if not ok or type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return false end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if type(f) ~= "function" then return false end
  local ok2, _, _, _, loc = pcall(f, link)
  return ok2 and loc == "INVTYPE_2HWEAPON"
end

-- 7-oct (auditoria): en la Off Hand hay un arma de una mano (llevas dos armas): una One-Hand nueva puede ir a cualquiera de las dos
local function armaEnOffHand()
  if type(GetInventoryItemLink) ~= "function" then return false end
  local ok, link = pcall(GetInventoryItemLink, "player", 17)
  if not ok or type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return false end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if type(f) ~= "function" then return false end
  local ok2, _, _, _, loc = pcall(f, link)
  return ok2 and (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND")
end

-- 7-oct (dos armas): sabes Dual Wield (CanDualWield) y no llevas un arma de dos manos: una One-Hand nueva tambien vale para
-- la Off Hand (aunque este vacia). Sin dato (funcion que no existe o falla) = false, como antes.
local function dobleArma()
  if type(CanDualWield) ~= "function" then return false end
  local ok, si = pcall(CanDualWield)
  if not ok or (issecretvalue and issecretvalue(si)) or not si then return false end
  return not dosManosPuesta()
end

-- 7-oct (amigo de Andy, Rogue con Pronged Reaver en la Off Hand: se la recomendaba para la Main Hand): una pieza que YA TIENES
-- nunca se recomienda. Se mira por itemID (sin el sufijo aleatorio): puesta en cualquier ranura (1-19, las dos manos, los dos
-- anillos, los dos trinkets), en las bolsas o en el banco. nil = no la tienes; si no, { donde = "puesta"|"bolsas"|"banco",
-- ranura = (solo puesta), texto = frase corta para mostrar }.
local function idPuesto(s)
  if type(GetInventoryItemLink) == "function" then
    local ok, l = pcall(GetInventoryItemLink, "player", s)
    if ok and type(l) == "string" and not (issecretvalue and issecretvalue(l)) then return idDe(l) end
  end
  return numero(llamar(GetInventoryItemID, "player", s))
end
local function cuantas(id, conBanco)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  return numero(llamar(f, id, conBanco and true or nil)) or 0
end
function WowF.yaLaTienes(id)
  id = tonumber(id)
  if not id then return nil end
  for s = 1, 19 do
    if idPuesto(s) == id then
      return { donde = "puesta", ranura = s, texto = L("ya la llevas puesta" .. (NOMBRE_RANURA[s] and (" (" .. NOMBRE_RANURA[s] .. ")") or ""),
        "you already wear it" .. (NOMBRE_RANURA[s] and (" (" .. NOMBRE_RANURA[s] .. ")") or "")) }
    end
  end
  local bolsas = cuantas(id, false)
  if bolsas > 0 then return { donde = "bolsas", texto = L("ya la tienes en las bolsas", "you already have it in your bags") } end
  if cuantas(id, true) > bolsas then return { donde = "banco", texto = L("ya la tienes en el banco", "you already have it in your bank") } end
  return nil
end
local function puestaEnAlgunaRanura(id)
  id = tonumber(id)
  if not id then return false end
  for s = 1, 19 do if idPuesto(s) == id then return true end end
  return false
end

-- Pieza del botin a la misma forma: st = { [id] = valor }
local function delBotin(o)
  local st, l = {}, o.st or {}
  for i = 1, #l - 1, 2 do st[l[i]] = (st[l[i]] or 0) + l[i + 1] end
  return { st = st, ar = o.ar or 0, dps = o.dps or 0 }
end

local function puntuar(x, pesos, distancia)
  local p = 0
  for id, v in pairs(x.st) do p = p + (pesos[id] or 0) * v end
  if pesos.ar then p = p + (x.ar or 0) * pesos.ar end
  if (x.dps or 0) > 0 then p = p + x.dps * ((distancia and pesos.dpsDist or pesos.dps) or 0) end
  return p
end

local function sumar(a, b)
  local r = { st = {}, ar = (a.ar or 0) + (b.ar or 0), dps = (a.dps or 0) + (b.dps or 0), link = a.link or b.link,
    incierto = a.incierto or b.incierto }
  for id, v in pairs(a.st) do r.st[id] = v end
  for id, v in pairs(b.st) do r.st[id] = (r.st[id] or 0) + v end
  return r
end

local function cifra(v) if math.abs(v - math.floor(v)) < 0.05 then return tostring(math.floor(v + 0.5)) end return string.format("%.1f", v) end
local function unir(lista)
  if #lista <= 1 then return lista[1] or "" end
  return table.concat(lista, ", ", 1, #lista - 1) .. L(" y ", " and ") .. lista[#lista]
end

-- 5-oct: texto de cuanto mejora una pieza (pct en %: 12 = +12 %). Si lo que llevas casi no da estadisticas el porcentaje sale
-- enorme (+2993 %) y no dice nada: por encima de 200 % se dice "mucho mejor". Para ordenar se sigue usando el numero real.
function WowF.textoMejora(pct)
  pct = tonumber(pct) or 0
  if pct > 200 then return L("mucho mejor", "much better") end
  return "+" .. math.floor(pct + 0.5) .. " %"
end

-- 7-oct (Rogue Subtlety/Assassination): Backstab, Ambush y Mutilate piden Dagger en la Main Hand. p.daga = nivel desde el que
-- rige (wowF_Datos.lua, de armaPrincipal en reglas.js). Otra arma de una mano solo vale para la Off Hand.
local function conDaga(p)
  if not p or not p.daga or p.daga <= 0 then return false end
  return (numero(llamar(UnitLevel, "player")) or 0) >= p.daga
end
local function subclaseDe(o)
  if o.s then return o.s end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local clave = o.link or o.id
  if type(f) ~= "function" or not clave then return nil end
  local ok, _, _, _, _, _, clase, sub = pcall(f, clave)
  if not ok or (issecretvalue and (issecretvalue(clase) or issecretvalue(sub))) then return nil end
  if clase ~= 2 then return nil end
  return tonumber(sub)
end
WowF.subclaseArma = subclaseDe
-- 12-oct (auditoria de mejoras): reglas de manos, daga y tipo de arma de tu rama para un hueco (sin comparar con lo puesto).
-- La usa "te dura hasta" de wowF_EquipoGuia.lua: una Two-Hand para un tanque con escudo no acorta lo que llevas.
function WowF.vaEnRanuraRama(o, p, s)
  if type(o) ~= "table" then return true end
  if o.inv == 17 and p and p.manos == "unaManoEscudo" then return false end
  if (o.inv == 13 or o.inv == 21) and s == 16 and conDaga(p) then
    local sub = subclaseDe(o)
    if sub and sub ~= 15 then return false end
  end
  if WowF.ajusteArma and (s == 16 or s == 17 or s == 18) then
    local ok, a = pcall(WowF.ajusteArma, o, p, s)
    if ok and type(a) == "table" and a.prohibido then return false end
  end
  return true
end

-- 12-oct (auditoria: Mail a un Shaman de 16, Plate a un Warrior de 30): puede tu clase llevar este tipo de arma o armadura, y desde
-- que nivel. Datos de la clase en wowF_Valiosos.lua (WowF.nivelDeUso). Devuelve ok, desde, nota:
--   ok = false: no te sirve (tu clase nunca lo lleva, lo aprende despues del tope de la beta, o el objeto pide mas que el tope);
--   nota = el motivo (o, si ok, "tu clase aprende X al nivel N" cuando aun no llegas). Sin datos para saberlo: true (no se adivina).
local NOMBRE_ARMADURA = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shield", [7] = "Libram", [8] = "Idol", [9] = "Totem" }
local NOMBRE_ARMA = { [0] = "One-Handed Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "One-Handed Maces", [5] = "Two-Handed Maces",
  [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords", [10] = "Staves", [13] = "Fist Weapons", [15] = "Daggers", [16] = "Thrown",
  [18] = "Crossbows", [19] = "Wands" }
local ARMA_INV_USO = { [13] = true, [15] = true, [17] = true, [21] = true, [22] = true, [25] = true, [26] = true }
local function claseSubDe(o)
  if o.cl and o.s then return o.cl, o.s end
  -- 12-oct: pieza de nuestros datos (s = tipo de arma, inv = hueco): no hace falta preguntarle al cliente (puede no tenerla en cache)
  if o.s and ARMA_INV_USO[tonumber(o.inv) or -1] then return 2, tonumber(o.s) end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local clave = o.link or o.id
  if type(f) ~= "function" or not clave then return nil end
  local ok, _, _, _, _, _, clase, sub = pcall(f, clave)
  if not ok or (issecretvalue and (issecretvalue(clase) or issecretvalue(sub))) then return nil end
  return tonumber(clase), tonumber(sub)
end
function WowF.usoDeClase(o, inv, nivel)
  if type(o) ~= "table" then return true end
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  local pide = tonumber(o.nivel)
  -- 12-oct: pieza leida de un enlace (WowF.piezaDeEnlace no trae el nivel): el que pide el objeto, del cliente
  if not pide and (o.link or o.id) then
    local fI = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local okI, _, _, _, _, rl = pcall(fI or function() end, o.link or o.id)
    if okI then pide = numero(rl) end
  end
  pide = pide or 0
  if pide > tope then
    return false, pide, L("pide nivel " .. pide .. " y la beta llega al " .. tope, "requires level " .. pide .. " and the beta caps at " .. tope)
  end
  local tk = llamar(function() local _, t = UnitClass("player"); return t end)
  if type(tk) ~= "string" or not WowF.nivelDeUso or not (WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[tk]) then return true end
  local clase, sub = claseSubDe(o)
  if clase ~= 2 and clase ~= 4 then return true end
  local desde, aprende = WowF.nivelDeUso(tk, { clase = clase, sub = sub, rl = pide }, inv or o.inv)
  local tipo = (clase == 4 and NOMBRE_ARMADURA[sub or -1]) or (clase == 2 and NOMBRE_ARMA[sub or -1]) or nil
  if not desde then
    return false, nil, tipo and L("tu clase no puede llevar " .. tipo, "your class cannot use " .. tipo) or L("tu clase no puede llevarlo", "your class cannot use it")
  end
  aprende = aprende or 0
  if aprende > tope then
    return false, desde, L("tu clase aprende " .. (tipo or "este tipo") .. " al nivel " .. aprende .. " y la beta llega al " .. tope .. ": hoy no puedes llevarlo",
      "your class learns " .. (tipo or "this type") .. " at level " .. aprende .. " and the beta caps at " .. tope .. ": you cannot use it yet")
  end
  if desde > tope then
    return false, desde, L("pide nivel " .. desde .. " y la beta llega al " .. tope, "requires level " .. desde .. " and the beta caps at " .. tope)
  end
  if aprende > (tonumber(nivel) or 0) then
    return true, desde, L("tu clase aprende " .. (tipo or "este tipo") .. " al nivel " .. aprende, "your class learns " .. (tipo or "this type") .. " at level " .. aprende)
  end
  return true, desde, nil
end

-- 7-oct (lanzadores: Staff frente a One-Hand + Held In Off-hand, como mejoresGrupo/pareja de app.js): con un arma de dos manos
-- puesta, una One-Hand o una Held In Off-hand nueva (o Shield en Elemental) se compara como PAREJA: la nueva + la mejor de la
-- otra mano que ya tengas en las bolsas, contra lo puesto. Solo ramas de lanzador (p.manos); el resto no cambia.
local PAREJA_MANOS = {
  lanzador = { main = { [13] = true, [21] = true }, off = { [23] = true } },
  lanzadorEscudo = { main = { [13] = true, [21] = true }, off = { [23] = true, [14] = true } },
}
-- La mejor pieza de las bolsas de esos tipos (inv) para esa mano (slot), con los pesos y la regla de arma de tu rama.
-- Solo lo que tu clase puede llevar YA (tipo y nivel). nil = no tienes ninguna (o no se pudieron leer las bolsas).
local function mejorEnBolsas(tipos, p, slot)
  local C = C_Container
  local huecos = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  local enlace = (C and C.GetContainerItemLink) or GetContainerItemLink
  local fInst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local fInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(huecos) ~= "function" or type(enlace) ~= "function" or type(fInst) ~= "function" or not WowF.piezaDeEnlace then return nil end
  local nivel = numero(llamar(UnitLevel, "player")) or 1
  local tk = llamar(function() local _, t = UnitClass("player"); return t end)
  local mejor
  for bolsa = 0, 4 do
    for h = 1, numero(llamar(huecos, bolsa)) or 0 do
      local l = llamar(enlace, bolsa, h)
      if type(l) == "string" and l ~= "" then
        local ok, _, _, _, loc = pcall(fInst, l)
        local inv = ok and type(loc) == "string" and not (issecretvalue and issecretvalue(loc)) and WowF.INV_DE_LOC and WowF.INV_DE_LOC[loc]
        local vale = inv and tipos[inv]
        -- tu clase lo lleva y tienes el nivel (si no se puede comprobar, no se cuenta)
        if vale and type(tk) == "string" and WowF.nivelDeUso and type(fInfo) == "function" then
          local r = { pcall(fInfo, l) }
          if not r[1] or r[2] == nil then vale = false
          else
            local desde = WowF.nivelDeUso(tk, { q = numero(r[4]), rl = numero(r[6]) or 0, clase = numero(r[13]), sub = numero(r[14]) }, inv)
            if not desde or desde > nivel then vale = false end
          end
        end
        local pz = vale and WowF.piezaDeEnlace(l)
        if pz then
          local x = delBotin(pz)
          x.link, x.id, x.incierto = l, pz.id, pz.incierto
          local f = 1
          if WowF.ajusteArma then
            local a = WowF.ajusteArma(x, p, slot)
            f = a.prohibido and 0 or (a.f or 1)
          end
          local pt = puntuar(x, pesosDe(p), false) * f
          if pt > 0 and (not mejor or pt > mejor.p) then mejor = { x = x, p = pt, n = l:match("%[(.-)%]") or "?" } end
        end
      end
    end
  end
  return mejor
end
-- nil = no aplica; si no, { slot = mano de la pieza nueva, otra = mejor pieza de la otra mano en las bolsas (o nil), falta = su tipo }
local function parejaStaff(o, p)
  local t = PAREJA_MANOS[(p and p.manos) or ""]
  if not t then return nil end
  local esMain, esOff = t.main[o.inv or 0], t.off[o.inv or 0]
  if not esMain and not esOff then return nil end
  if not dosManosPuesta() then return nil end
  local falta = "One-Hand"
  if esMain then falta = (p.manos == "lanzadorEscudo") and L("Held In Off-hand o Shield", "Held In Off-hand or Shield") or "Held In Off-hand" end
  return { slot = esMain and 16 or 17, otra = mejorEnBolsas(esMain and t.off or t.main, p, esMain and 17 or 16), falta = falta }
end

-- Compara una pieza del botin con lo que llevas (sin decir quien la suelta).
-- Devuelve sirve, la explicacion y segura (true = comparada de verdad con lo puesto, o la ranura esta vacia).
local contarTuyas = false -- 7-oct: WowF.piezasParaTi(p, inst, true) (dentro de la mazmorra): la que acabas de conseguir sigue en la lista
local function compararSinQuien(o, p)
  local pesos = pesosDe(p)
  local ranuras = RANURA[o.inv or 0]
  if not pesos or not ranuras then return true, nil, false end
  indexar(p)
  local distancia = DISTANCIA[o.inv] or false
  local nueva = delBotin(o)
  local pNueva = puntuar(nueva, pesos, distancia)
  -- Sin estadisticas que cuenten para tu rama (solo un efecto especial): no se puede afirmar que sea mejor
  if pNueva <= 0 then return false, nil, false end
  -- 8-oct (armas): pide un nivel por encima del tope de la beta: aun no se puede llevar, no se recomienda
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  if (o.nivel or 0) > tope then
    return false, nil, false, nil, { nivelAlto = o.nivel, armaNo = L("pide nivel " .. o.nivel .. " y la beta llega al " .. tope, "requires level " .. o.nivel .. " and the beta caps at " .. tope) }
  end
  -- 12-oct (auditoria): tu clase lleva ese tipo de arma o armadura (y lo aprende antes del tope de la beta)
  local okUso, _, notaClase = WowF.usoDeClase(o, o.inv, numero(llamar(UnitLevel, "player")) or 0)
  if not okUso then return false, nil, false, nil, { armaNo = notaClase, noClase = true } end
  -- Arma en la Off Hand: solo con Dual Wield (si el juego dice que no lo sabes)
  if o.inv == 22 and type(CanDualWield) == "function" then
    local okD, si = pcall(CanDualWield)
    if okD and si == false then
      return false, nil, false, nil, { armaNo = L("necesitas Dual Wield para llevar un arma en la Off Hand", "you need Dual Wield to use a weapon in the Off Hand") }
    end
  end
  -- 9-oct: tu rama lleva arma One-Hand + Shield (tanque): una Two-Hand nunca es mejora
  if o.inv == 17 and p and p.manos == "unaManoEscudo" then
    return false, nil, false, nil, { armaNo = L("tu rama lleva arma One-Hand + Shield", "your spec uses a One-Hand weapon + Shield") }
  end
  -- 7-oct: ya la tienes (puesta en cualquier ranura; del botin, tambien en las bolsas o en el banco): no se recomienda
  if o.id and not o.link and not contarTuyas and WowF.yaLaTienes(o.id) then return false, nil, false end
  if o.id and o.link and puestaEnAlgunaRanura(o.id) then return false, nil, false end
  -- 7-oct: lanzador con arma de dos manos puesta: One-Hand / Held In Off-hand (Shield en Elemental) como PAREJA (parejaStaff)
  local par = parejaStaff(o, p)
  -- Off Hand / Shield / Held In Off-hand con un arma de dos manos puesta: no la puedes llevar
  if not par and (o.inv == 14 or o.inv == 22 or o.inv == 23) and dosManosPuesta() then return false, nil, false end
  local NOLEE = L("No se pudo leer lo que llevas en esa ranura: comparalo tu", "Could not read what you wear in that slot: compare it yourself")
  local VACIA = L("No llevas nada en esa ranura", "You have nothing in that slot")
  if o.inv == 13 and (armaEnOffHand() or dobleArma()) then ranuras = { 16, 17 } end
  if (o.inv == 13 or o.inv == 21) and conDaga(p) then
    local sub = subclaseDe(o)
    if sub and sub ~= 15 then
      if o.inv == 21 then return false, nil, false end
      ranuras = { 17 }
    end
  end
  if par then ranuras = { par.slot } end
  -- 8-oct (armas): regla de arma de tu rama por mano (wowF_Armas.lua): tipo prohibido = esa mano no cuenta; velocidad que no
  -- toca y racial de arma = factor sobre la puntuacion (de lo nuevo Y de lo puesto, para comparar igual con igual)
  local aj, ajMalo = {}, nil
  if WowF.ajusteArma then
    local quedan = {}
    for _, s in ipairs(ranuras) do
      local a = WowF.ajusteArma(o, p, s)
      if a.prohibido then ajMalo = ajMalo or a.malo else aj[s] = a; table.insert(quedan, s) end
    end
    if #quedan == 0 then return false, nil, false, nil, { armaNo = ajMalo } end
    ranuras = quedan
  end
  local function factorPuesto(x, s)
    if not WowF.ajusteArma or not x or not (x.id or x.link) then return 1 end
    local a = WowF.ajusteArma(x, p, s)
    return a.prohibido and 0 or a.f
  end
  -- Lo que llevas: la peor de las dos (anillos, trinkets); Two-Hand contra Main Hand + Off Hand
  -- (con la regla de arma: la mano donde lo nuevo gana mas)
  local vieja, pVieja, ranuraVieja, mejorGana = nil, nil, nil, nil
  -- 12-oct (auditoria: toda mejora dice el porque con numeros): ranura vacia = lo que ganas son las estadisticas de la pieza
  -- que cuentan para tu rama (las 3 de mas peso), para que WowF.porQueMejora tambien lo diga
  local function detVacia(s, a)
    local g = {}
    for id, v in pairs(nueva.st) do
      local w = pesos[id] or 0
      if w > 0 and v > 0 then table.insert(g, { n = STAT[id] and STAT[id][2] or ("stat " .. id), d = v, peso = w, efecto = v * w }) end
    end
    if (nueva.ar or 0) > 0 and (pesos.ar or 0) > 0 then table.insert(g, { n = "Armor", d = nueva.ar, peso = pesos.ar, efecto = nueva.ar * pesos.ar }) end
    local wd = (distancia and pesos.dpsDist or pesos.dps) or 0
    if (nueva.dps or 0) > 0 and wd > 0 then table.insert(g, { n = "DPS", d = nueva.dps, peso = wd, efecto = nueva.dps * wd }) end
    table.sort(g, function(x, y) return x.efecto > y.efecto end)
    while #g > 3 do table.remove(g) end
    return { slot = s, vacia = true, ganas = g, pierdes = {}, G = pNueva, P = 0, rama = p.ramaPesos or p.ramaNombre or "",
      arma = a and ((a.malo ~= "" and a.aunque) or a.porque) or nil, clase = notaClase }
  end
  if par then
    -- contra el arma de dos manos entera (Main Hand), con su regla de arma
    local x = puesto(16)
    if x == false then return true, NOLEE, false end
    x = x or { st = {}, ar = 0, dps = 0 }
    vieja, pVieja, ranuraVieja = x, puntuar(x, pesos, distancia) * factorPuesto(x, 16), par.slot
  end
  for _, s in ipairs(par and {} or ranuras) do
    local x = puesto(s)
    if x == false then return true, NOLEE, false end
    if x == nil and o.inv ~= 17 then
      local a = aj[s]
      return true, VACIA, true, nil, detVacia(s, a)
    end
    x = x or { st = {}, ar = 0, dps = 0 }
    local px = puntuar(x, pesos, distancia) * factorPuesto(x, s)
    local gana = pNueva * ((aj[s] and aj[s].f) or 1) - px
    if not mejorGana or gana > mejorGana then vieja, pVieja, ranuraVieja, mejorGana = x, px, s, gana end
  end
  local ajN = aj[ranuraVieja]
  if ajN then pNueva = pNueva * ajN.f end
  local nombreRanura = NOMBRE_RANURA[ranuraVieja] or ""
  local nota2m
  if par then
    local dos = (subclaseDe({ link = vieja.link, id = vieja.id }) == 10) and "Staff" or "Two-Hand"
    nombreRanura = dos
    if par.otra then
      nueva = sumar(nueva, par.otra.x); pNueva = pNueva + par.otra.p
      nota2m = L("con " .. par.otra.n .. " en la otra mano suma más que tu " .. dos, "with " .. par.otra.n .. " in the other hand it beats your " .. dos)
    else
      nota2m = L("necesitas también " .. par.falta .. " para dejar el " .. dos, "you also need " .. par.falta .. " to drop the " .. dos)
    end
  end
  if o.inv == 17 then
    local izq = puesto(17)
    if izq == false then return true, NOLEE, false end
    if izq then
      local pIzq = puntuar(izq, pesos, distancia) * factorPuesto(izq, 17)
      vieja = sumar(vieja, izq); pVieja = pVieja + pIzq; nombreRanura = "Main Hand + Off Hand"
    end
    if not vieja.link then return true, VACIA, true, nil, detVacia(16, aj[16]) end
  end
  if pNueva <= pVieja + 0.05 then
    -- el porque de la mano donde mas perdia (o de cualquier mano con regla, si en la otra no ganaba por otras razones)
    local malo = (ajN and ajN.malo ~= "" and ajN.malo) or nil
    if not malo then for _, s in ipairs(ranuras) do if aj[s] and aj[s].malo ~= "" then malo = aj[s].malo; break end end end
    return false, nil, false, nil, { armaNo = malo }
  end
  -- Lo puesto tiene un efecto "Equip:" que no se pudo leer: se muestra, pero sin afirmar que sea mejor
  if vieja.incierto then
    return true, L("Lo que llevas en " .. nombreRanura .. " tiene un efecto que no se pudo leer: comparalo tu",
      "What you wear in " .. nombreRanura .. " has an effect that could not be read: compare it yourself"), false
  end
  -- Diferencias que cuentan para tu rama (con peso), de mayor a menor efecto
  local difs = {}
  local function anotar(nombre, d, peso) if math.abs(d) >= 0.05 and peso > 0 then table.insert(difs, { n = nombre, d = d, peso = peso, efecto = math.abs(d) * peso }) end end
  local ids = {}
  for id in pairs(nueva.st) do ids[id] = true end
  for id in pairs(vieja.st) do ids[id] = true end
  for id in pairs(ids) do anotar(STAT[id] and STAT[id][2] or ("stat " .. id), (nueva.st[id] or 0) - (vieja.st[id] or 0), pesos[id] or 0) end
  anotar("Armor", (nueva.ar or 0) - (vieja.ar or 0), pesos.ar or 0)
  anotar("DPS", (nueva.dps or 0) - (vieja.dps or 0), (distancia and pesos.dpsDist or pesos.dps) or 0)
  table.sort(difs, function(a, b) return a.efecto > b.efecto end)
  local pierdes, ganas = {}, {}
  -- 7-oct (auditoria): G = lo que ganas con peso, P = lo que pierdes con peso (todas las diferencias, no solo las que se nombran)
  local G, P = 0, 0
  for _, x in ipairs(difs) do
    if x.d > 0 then G = G + x.efecto else P = P + x.efecto end
    if x.d < 0 and #pierdes < 2 then table.insert(pierdes, x) elseif x.d > 0 and #ganas < 3 then table.insert(ganas, x) end
  end
  local function lista(t) local r = {} for _, x in ipairs(t) do table.insert(r, cifra(math.abs(x.d)) .. " " .. x.n) end return unir(r) end
  local rama = p.ramaPesos or p.ramaNombre or ""
  local pct = (pVieja > 0) and ((pNueva - pVieja) / pVieja * 100) or 0
  local mejora = (pVieja > 0) and (WowF.textoMejora(pct) .. ((pct > 200) and L(" para tu puntuacion", " for your score") or L(" en tu puntuacion", " to your score")))
    or ("+" .. cifra(pNueva - pVieja) .. L(" puntos en tu puntuacion", " points to your score"))
  local texto
  if #pierdes == 0 then
    texto = L("Ganas ", "You gain ") .. lista(ganas) .. " -> " .. mejora .. L(" (rama " .. rama .. ")", " (" .. rama .. " spec)")
  else
    local razon
    if ganas[1] and ganas[1].peso > pierdes[1].peso then
      razon = L("para tu rama (" .. rama .. ") " .. ganas[1].n .. " vale mas que " .. pierdes[1].n, "for your spec (" .. rama .. ") " .. ganas[1].n .. " is worth more than " .. pierdes[1].n)
    else
      razon = L("para tu rama (" .. rama .. ") lo que ganas suma mas que lo que pierdes", "for your spec (" .. rama .. ") what you gain outweighs what you lose")
    end
    texto = L("Pierdes ", "You lose ") .. lista(pierdes) .. L(", pero ganas ", ", but you gain ") .. lista(ganas) .. ": " .. razon .. " -> " .. mejora
  end
  if par then texto = texto .. L(": mejor que tu " .. nombreRanura, ": better than your " .. nombreRanura)
  elseif nombreRanura ~= "" then texto = texto .. L(": mejor que lo que llevas en " .. nombreRanura, ": better than your current " .. nombreRanura) end
  if nota2m then texto = texto .. ". " .. (nota2m:gsub("^%l", string.upper)) end
  -- 7-oct (auditoria, caso del amigo: mas Agility y menos Stamina): mejora DUDOSA = pierdes algo que cuenta para tu rama y
  -- (lo perdido vale al menos la mitad de lo ganado, o la mejora total es menor del 5 %). Se muestra, pero no como mejora segura.
  local dudosa = P > 0 and (P >= 0.5 * G or (pVieja > 0 and pct < 5))
  if dudosa then texto = L("Mejora pequeña, depende: ", "Small upgrade, it depends: ") .. texto end
  local det = { ganas = ganas, pierdes = pierdes, G = G, P = P, dudosa = dudosa, rama = rama, ranura = nombreRanura,
    pct = (pVieja > 0) and pct or nil, slot = ranuraVieja, pareja = nota2m, clase = notaClase,
    arma = ajN and (((ajN.malo ~= "" and ajN.aunque ~= "") and (ajN.aunque .. (ajN.porque ~= "" and ("; " .. ajN.porque) or ""))) or (ajN.porque ~= "" and ajN.porque) or nil) or nil }
  -- 4.o valor: cuanto mejora (0.10 = +10 %), para que el aviso de botin solo hable de mejoras de verdad; 5.o: el detalle (WowF.porQueMejora)
  return true, texto, not dudosa, (pVieja > 0) and ((pNueva - pVieja) / pVieja) or nil, det
end

-- 7-oct (Andy: "que diga en pocas palabras POR QUE es mejora"): una linea corta con lo que ganas y lo que pierdes, con numeros,
-- de mas a menos peso para tu rama. det = 5.o valor de WowF.compararPieza (o e.det de WowF.evaluarMejora). nil = nada que decir.
--   "+6 Agility, +2 Armor; pierdes 3 Stamina (vale menos para Combat)"
--   "+2 Agility; pierdes 5 Stamina (casi se compensa para Combat: mejora pequeña, depende)"
function WowF.porQueMejora(det)
  if type(det) ~= "table" or type(det.ganas) ~= "table" or #det.ganas == 0 then return nil end
  local partes = {}
  for _, x in ipairs(det.ganas) do table.insert(partes, "+" .. cifra(math.abs(x.d)) .. " " .. x.n) end
  local t = table.concat(partes, ", ")
  local rama = det.rama or ""
  local pierdes = det.pierdes or {}
  if #pierdes > 0 then
    local p = {}
    for _, x in ipairs(pierdes) do table.insert(p, cifra(math.abs(x.d)) .. " " .. x.n) end
    t = t .. L("; pierdes ", "; you lose ") .. unir(p)
    if det.dudosa then
      t = t .. L(" (casi se compensa para " .. rama .. ": mejora pequeña, depende)", " (nearly evens out for " .. rama .. ": small upgrade, it depends)")
    else
      t = t .. L(" (vale menos para " .. rama .. ")", " (worth less for " .. rama .. ")")
    end
  elseif det.vacia then
    t = t .. L(" (la ranura está vacía)", " (the slot is empty)")
  elseif det.pct and det.pct < 3 then
    t = t .. L(" (mejora pequeña)", " (small upgrade)")
  end
  -- 8-oct (armas): por que el arma te va (velocidad, tipo, racial) o "aunque es rapida..."
  if type(det.arma) == "string" and det.arma ~= "" then t = t .. "; " .. det.arma end
  -- 7-oct: lanzador con Staff: con que pieza de la otra mano gana (o que le falta)
  if type(det.pareja) == "string" and det.pareja ~= "" then t = t .. "; " .. det.pareja end
  -- 12-oct: "tu clase aprende Polearms al nivel 20"
  if type(det.clase) == "string" and det.clase ~= "" then t = t .. "; " .. det.clase end
  return t
end

-- Compara una pieza del botin con lo que llevas. Devuelve sirve (true/false), la explicacion y si es una mejora segura
-- (false = no se pudo leer lo puesto: se muestra, pero sin decir "pide Need").
function WowF.compararPieza(o, p)
  local sirve, texto, segura, cuanto, det = compararSinQuien(o, p)
  -- 8-oct: tambien cuando no sirve se pasa el detalle (det.armaNo = por que el arma no te la recomiendo)
  if not sirve or not texto then return sirve, texto, segura, cuanto, det end
  -- Quien la suelta (solo si es un jefe de la mazmorra segun la beta) y el nivel que pide si aun no lo tienes
  -- 12-oct (auditoria): ranura vacia = tambien lo que ganas, con numeros ("No llevas nada en esa ranura: +3 Intellect, +32 Armor")
  if type(det) == "table" and det.vacia and type(det.ganas) == "table" and #det.ganas > 0 then
    local g = {}
    for _, x in ipairs(det.ganas) do g[#g + 1] = "+" .. cifra(math.abs(x.d)) .. " " .. x.n end
    texto = texto .. ": " .. table.concat(g, ", ")
  end
  if o.esJefe and o.jefe then texto = L("Jefe: ", "Boss: ") .. o.jefe .. ". " .. texto end
  local nivel = numero(llamar(UnitLevel, "player"))
  if nivel and (o.nivel or 0) > nivel then texto = texto .. L(". Pide nivel ", ". Requires level ") .. o.nivel end
  if type(det) == "table" and type(det.clase) == "string" and det.clase ~= "" then texto = texto .. ". " .. (det.clase:gsub("^%l", string.upper)) end
  return sirve, texto, segura, cuanto, det
end

-- Piezas de una mazmorra que de verdad mejoran lo que llevas (como mucho 8), cada una con o.porque.
-- o.mejora = true solo si se comparo de verdad con lo puesto (o la ranura esta vacia)
-- conTuyas (solo el panel DENTRO de la mazmorra): la pieza que ya conseguiste (en las bolsas o en el banco, no puesta) sigue
-- en la lista, con o.tienes = "bolsas"|"banco", para marcarla "[ya la tienes]". Sin conTuyas, lo que ya tienes no sale.
function WowF.piezasParaTi(p, inst, conTuyas)
  local lista = p and p.botin and p.botin[inst]
  if not lista then return nil end
  local r = {}
  for _, o in ipairs(lista) do
    o.tienes = nil
    if conTuyas then
      local ya = WowF.yaLaTienes(o.id)
      if ya and ya.donde ~= "puesta" then o.tienes = ya.donde end
    end
    contarTuyas = o.tienes and true or false
    local okc, sirve, porque, segura, _, det = pcall(WowF.compararPieza, o, p)
    contarTuyas = false
    if not okc then error(sirve, 0) end
    if sirve and #r < 8 then
      o.porque = porque; o.mejora = segura and true or false
      -- 7-oct: o.dudosa = mejora pequena (pierdes algo que cuenta); o.porqueCorto = la linea corta de WowF.porQueMejora
      o.dudosa = (type(det) == "table" and det.dudosa) and true or nil
      o.porqueCorto = WowF.porQueMejora(det)
      table.insert(r, o)
    end
  end
  return r
end

-- 5-oct (Andy: "que la ficha explique por que hay pocas piezas"): por que en una mazmorra hay pocas piezas (o ninguna) para ti.
-- Usa el botin de TU rama a tu nivel (p.botin, ya filtrado por clase, rama y nivel) y el arma de la rama (p.manos, de reglas.js).
-- suyas = las que mejoran lo que llevas (WowF.piezasParaTi). nil = hay bastantes, no hace falta explicar.
local ARMAS_DE = { dosManos = { [17] = true }, dobleEmpunadura = { [13] = true, [21] = true, [22] = true },
  unaManoEscudo = { [13] = true, [21] = true, [14] = true }, lanzadorEscudo = { [13] = true, [21] = true, [17] = true, [14] = true }, lanzador = { [13] = true, [21] = true, [17] = true, [23] = true },
  cazador = { [15] = true, [25] = true, [26] = true }, dosManosOEscudo = { [13] = true, [17] = true, [21] = true, [14] = true } }
local TIPO_ARMA = { dosManos = { "de dos manos (Two-Hand)", "Two-Hand" }, cazador = { "a distancia (Ranged)", "Ranged" } }
function WowF.porQuePocas(p, inst, suyas)
  suyas = suyas or {}
  if not p or #suyas >= 4 then return nil end
  local lista = (p.botin and p.botin[inst]) or {}
  local nivel = numero(llamar(UnitLevel, "player")) or 0
  local rama = ((p.ramaCambio or 0) > 0 and nivel < p.ramaCambio and p.ramaSubir and p.ramaSubir ~= "") and p.ramaSubir or (p.ramaNombre or p.rama or "?")
  -- 6-oct (regla de Andy: dato sin confirmar = aviso): si Wowhead /forever aun no tiene el botin de esta mazmorra (bv = false:
  -- Uldaman, Razorfen Downs, las nuevas de Forever como Excavation Site: Wetlands) no se dice "no cae nada": no se sabe todavia
  local sinConfirmar = false
  for _, m in ipairs(WowFMazmorras or {}) do if m.i == inst and m.bv == false then sinConfirmar = true end end
  if sinConfirmar and #lista == 0 then
    return L("El botín de esta mazmorra aún no está confirmado en WoW Forever: no te recomiendo piezas que no se puedan comprobar. Se actualizará en próximas actualizaciones.",
      "This dungeon's loot is not confirmed in WoW Forever yet: no items are recommended until they can be checked. This will be updated in future updates.")
  end
  if #lista == 0 then
    return L("Aquí no cae nada para tu rama (" .. rama .. ") a tu nivel.", "Nothing here drops for your spec (" .. rama .. ") at your level.")
  end
  local partes = {}
  local armas, hayArma = ARMAS_DE[p.manos or ""], false
  for _, o in ipairs(lista) do if armas and armas[o.inv or 0] then hayArma = true end end
  if armas and not hayArma then
    local tipo = TIPO_ARMA[p.manos]
    table.insert(partes, tipo and L("Aquí no cae ningún arma " .. tipo[1] .. " para tu rama (" .. rama .. ") a tu nivel",
      "No " .. tipo[2] .. " weapon for your spec (" .. rama .. ") drops here at your level")
      or L("Aquí no cae ningún arma para tu rama (" .. rama .. ") a tu nivel", "No weapon for your spec (" .. rama .. ") drops here at your level"))
  end
  local nombres = {}
  for _, o in ipairs(lista) do table.insert(nombres, o.n or "?") end
  local juntos = (#nombres == 1) and nombres[1] or (table.concat(nombres, ", ", 1, #nombres - 1) .. L(" y ", " and ") .. nombres[#nombres])
  if #nombres <= 4 then
    table.insert(partes, (#nombres == 1) and L("para ti solo hay " .. juntos, "the only piece for you is " .. juntos)
      or L("para ti solo hay " .. #nombres .. ": " .. juntos, "only " .. #nombres .. " pieces are for you: " .. juntos))
  else
    table.insert(partes, L("para ti hay " .. #nombres .. " piezas", #nombres .. " pieces are for you"))
  end
  local quedan = #lista - #suyas
  -- 7-oct: las que ya tienes (puestas, en las bolsas o en el banco) se nombran aparte
  local tuyas = {}
  for _, o in ipairs(lista) do if WowF.yaLaTienes(o.id) then table.insert(tuyas, o.n or "?") end end
  if #tuyas > 0 then
    table.insert(partes, L("ya tienes " .. unir(tuyas), "you already have " .. unir(tuyas)))
    quedan = quedan - #tuyas
  end
  if quedan > 0 then
    table.insert(partes, (#suyas == 0) and L("ninguna mejora lo que llevas", "none beats what you wear")
      or L(quedan .. (quedan == 1 and " no mejora" or " no mejoran") .. " lo que llevas", quedan .. (quedan == 1 and " does not beat" or " do not beat") .. " what you wear"))
  end
  local t = table.concat(partes, "; ")
  return (t:gsub("^%l", string.upper)) .. "."
end

-- 4-oct (aviso de botin): una pieza a partir de su ENLACE (lo que te acaba de caer), con la forma que pide compararPieza:
-- { inv, st = { statId, valor, ... }, ar, dps, nivel, link, id, incierto }. Lee GetItemStats del enlace (incluye el sufijo
-- aleatorio de esa copia) y las lineas "Equip:" del tooltip. nil = no se pudo leer (sin datos en cache o valor secreto).
-- incierto = tiene un efecto "Equip:" que no se entiende: su valor real puede ser mayor que el calculado.
local INV_DE_LOC = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13,
  INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20,
  INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25,
  INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28 }
WowF.INV_DE_LOC = INV_DE_LOC
function WowF.piezaDeEnlace(link)
  if type(link) ~= "string" or link == "" or (issecretvalue and issecretvalue(link)) then return nil end
  local fInst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local ok, _, _, _, loc = pcall(fInst or function() end, link)
  if not ok or type(loc) ~= "string" or (issecretvalue and issecretvalue(loc)) then return nil end
  local inv = INV_DE_LOC[loc]
  if not inv then return nil end
  local f = (C_Item and C_Item.GetItemStats) or GetItemStats
  local t = llamar(f, link)
  if type(t) ~= "table" then return nil end
  local st, plana = {}, {}
  for sid, s in pairs(STAT) do
    local v = numero(t[s[1]]) or numero(t[(s[1]:gsub("_SHORT$", ""))])
    if v and v ~= 0 then st[sid] = v end
  end
  local incierto = false
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local datos = llamar(C_TooltipInfo.GetHyperlink, link)
    if type(datos) == "table" and type(datos.lines) == "table" then
      local prefijo = (type(ITEM_SPELL_TRIGGER_ONEQUIP) == "string" and ITEM_SPELL_TRIGGER_ONEQUIP) or "Equip:"
      for _, ln in ipairs(datos.lines) do
        local tx = type(ln) == "table" and ln.leftText or nil
        if tx ~= nil and issecretvalue and issecretvalue(tx) then incierto = true
        elseif type(tx) == "string" and tx:sub(1, #prefijo) == prefijo then
          if not lineaEquip("Equip:" .. tx:sub(#prefijo + 1), st) then incierto = true end
        end
      end
    end
  end
  for sid, v in pairs(st) do plana[#plana + 1] = sid; plana[#plana + 1] = v end
  return { inv = inv, st = plana, ar = numero(t.RESISTANCE0_NAME) or 0, dps = numero(t.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) or 0,
    link = link, id = idDe(link), incierto = incierto }
end

-- Lo puesto cambia: se vuelve a leer (el enlace ya sirve de clave, pero asi no crece sin limite)
if CreateFrame then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  f:SetScript("OnEvent", function() leidas = {} end)
end

-- ===================== 5-oct: evaluar UN objeto por su enlace =====================
-- Para el tooltip (wowF_TooltipMejora.lua) y la recompensa de mision (wowF_Recompensa.lua). Usa la misma comparacion de arriba
-- (pesos de tu rama, nunca el nivel de objeto). Devuelve nil si no es equipo que se compare (bolsa, camisa, tabardo, municion,
-- carcaj, no equipable) o si el cliente aun no tiene el objeto en cache. Si no, una tabla:
--   estado = "mejora" (segura) | "dudosa" (7-oct: mejora pequena, pierdes algo que cuenta) | "nomejora" | "noclase"
--            (tu clase nunca lo lleva) | "incierto" (no se pudo comparar de verdad)
--   porque (7-oct) = linea corta de WowF.porQueMejora (lo que ganas y lo que pierdes) en "mejora" y "dudosa"; det = el detalle
--            | "sinplan" (sin pesos de rama) | "puesto" (es lo que llevas)
--   cuanto (0.12 = +12 %; nil si la ranura esta vacia o lo puesto no suma nada para tu rama), vacia, desde (nivel desde el que
--   tu clase lo puede llevar), nivel (el tuyo), ranura (nombre del juego), rama, q, sell (cobre), bind, inv, link, id
local NO_COMPARAR = { [4] = true, [18] = true, [19] = true, [24] = true, [27] = true }
function WowF.nombreRanuraDeInv(inv)
  local r = RANURA[inv or 0]
  return r and NOMBRE_RANURA[r[1]] or nil
end
local function enlacePuesto(s)
  if type(GetInventoryItemLink) ~= "function" then return false end
  local ok, l = pcall(GetInventoryItemLink, "player", s)
  if not ok or (issecretvalue and issecretvalue(l)) then return false end
  if type(l) ~= "string" or l == "" then return nil end
  return l
end
-- 11-oct (diario): una pieza del botin contra lo que llevas en UNA ranura concreta (ventana "Comparar con lo puesto" del diario).
-- slots = ranuras posibles (anillos 11/12, abalorios 13/14, One-Hand 16/17 si llevas dos armas); slot = la elegida (o la 1.a).
-- vieja: false = no se pudo leer, nil = vacia, numero = su puntuacion. cuanto: 0.12 = +12 % (nil si no hay con que comparar).
function WowF.compararEnRanura(o, p, slot)
  if type(o) ~= "table" then return nil end
  local slots = RANURA[o.inv or 0]
  if not slots then return nil end
  if o.inv == 13 and (armaEnOffHand() or dobleArma()) then slots = { 16, 17 } end
  local r = { slots = slots, slot = slots[1] }
  for _, s in ipairs(slots) do if s == slot then r.slot = s end end
  r.ranura = NOMBRE_RANURA[r.slot]
  r.link = enlacePuesto(r.slot)
  local pesos = pesosDe(p)
  if not pesos then r.sinPesos = true; return r end
  indexar(p)
  local dist = DISTANCIA[o.inv] or false
  r.nueva = puntuar(delBotin(o), pesos, dist)
  local x = puesto(r.slot)
  if x == false then r.vieja = false; return r end
  if x == nil then r.vacia = true; return r end
  r.vieja = puntuar(x, pesos, dist)
  if r.vieja > 0 then r.cuanto = (r.nueva - r.vieja) / r.vieja end
  return r
end
function WowF.evaluarMejora(link, plan)
  if type(link) ~= "string" or link == "" or (issecretvalue and issecretvalue(link)) then return nil end
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, link) }
  if not r[1] or r[2] == nil then return nil end
  local q = numero(r[4])
  local loc = r[10]
  if not q or type(loc) ~= "string" or (issecretvalue and issecretvalue(loc)) then return nil end
  local inv = INV_DE_LOC[loc]
  if not inv or NO_COMPARAR[inv] or not RANURA[inv] then return nil end
  local i = { q = q, rl = numero(r[6]) or 0, clase = numero(r[13]), sub = numero(r[14]) }
  local e = { inv = inv, q = q, sell = numero(r[12]) or 0, bind = numero(r[15]), link = link, id = idDe(link),
    ranura = WowF.nombreRanuraDeInv(inv), nivel = numero(llamar(UnitLevel, "player")) or 1, desde = i.rl }
  -- Es lo que llevas puesto: nada que comparar. Ranura vacia (la Two-Hand mira solo la Main Hand)
  local ranuras = (inv == 17) and { 16 } or RANURA[inv]
  -- 7-oct: por itemID y en cualquier ranura (la One-Hand de la Off Hand, el otro anillo...), no solo por el enlace exacto
  if puestaEnAlgunaRanura(e.id) then e.estado = "puesto"; return e end
  for _, s in ipairs(ranuras) do
    local l = enlacePuesto(s)
    if l == link then e.estado = "puesto"; return e end
    if l == nil then e.vacia = true end
  end
  -- Tu clase: tipos de arma y armadura que aprende (wowF_Valiosos.lua, via WowF.nivelDeUso de wowF_AvisoBotin.lua)
  local okC, _, tk = pcall(UnitClass, "player")
  if okC and type(tk) == "string" and not (issecretvalue and issecretvalue(tk)) and WowF.nivelDeUso
    and WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[tk] then
    local desde, aprende = WowF.nivelDeUso(tk, i, inv)
    if not desde or desde > 60 then
      -- 12-oct (auditoria): tambien aqui el motivo ("your class cannot use Wands")
      e.estado = "noclase"
      local _, _, motivo = WowF.usoDeClase({ cl = i.clase, s = i.sub, nivel = i.rl, link = link, id = e.id }, inv, e.nivel)
      e.porque = motivo
      return e
    end
    e.desde = desde
    -- 12-oct (auditoria: Mail a un Shaman de 16): lo aprende despues del tope de la beta = hoy no lo puede llevar
    local okU, _, motivo = WowF.usoDeClase({ cl = i.clase, s = i.sub, nivel = i.rl, link = link, id = e.id }, inv, e.nivel)
    -- (o el objeto pide mas nivel que el tope): no es mejora, con el motivo en e.porque
    if not okU then e.estado = "noclase"; e.aprende = aprende; e.porque = motivo; return e end
  end
  -- 12-oct: el juego dice que no puedes usarlo (y no es por el nivel): no es mejora
  if C_PlayerInfo and type(C_PlayerInfo.CanUseItem) == "function" and e.id and (e.desde or 0) <= e.nivel then
    local okU, puede = pcall(C_PlayerInfo.CanUseItem, e.id)
    if okU and puede == false then
      e.estado = "noclase"; e.porque = L("el juego dice que no puedes usarlo", "the game says you cannot use it"); return e
    end
  end
  if plan == nil and WowF.armarPlan then
    local okP, p = pcall(WowF.armarPlan)
    plan = okP and p or nil
  end
  if type(plan) ~= "table" or not plan.pesos then e.estado = "sinplan"; return e end
  -- 5-oct (revision): la rama pasa por WowF.T (hoy son nombres del juego en ingles, pero sin mezclar idiomas si cambia)
  e.rama = plan.ramaPesos or plan.ramaNombre
  if type(e.rama) == "string" and WowF.T then e.rama = WowF.T(e.rama) end
  local pieza = WowF.piezaDeEnlace(link)
  if not pieza then e.estado = "incierto"; return e end
  local ok, sirve, _, segura, cuanto, det = pcall(WowF.compararPieza, pieza, plan)
  if not ok then e.estado = "incierto"; return e end
  if sirve and segura then e.estado = "mejora"; e.cuanto = cuanto; e.det = det; e.porque = WowF.porQueMejora(det)
  elseif sirve and type(det) == "table" and det.dudosa and not pieza.incierto then
    e.estado = "dudosa"; e.cuanto = cuanto; e.det = det; e.porque = WowF.porQueMejora(det)
  elseif sirve or pieza.incierto then e.estado = "incierto"
  else
    e.estado = "nomejora"
    -- 8-oct (armas): "no te la recomiendo: es rapida y tu Main Hand quiere lenta"
    if type(det) == "table" and type(det.armaNo) == "string" then e.porque = det.armaNo end
  end
  return e
end
