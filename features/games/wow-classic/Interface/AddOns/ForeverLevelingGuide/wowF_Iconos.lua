-- Forever Leveling Guide: icono REAL de cada hechizo, talento y objeto (12-oct, Andy: "que siempre sean los iconos de verdad...
-- mucha gente se fija por el icono"). Orden: datos de la beta de WoW Forever (WowFIconos, de SpellMisc) -> lo que diga el cliente
-- -> nil (quien llama decide su icono de reserva). Nunca un icono inventado para un hechizo que conocemos.
WowF = WowF or {}

local CARPETA = "Interface\\Icons\\"

local function ruta(v)
  if type(v) == "number" then return v end
  if type(v) == "string" and v ~= "" then
    if v:find("\\", 1, true) or v:find("/", 1, true) then return v end
    return CARPETA .. v
  end
  return nil
end

-- id de hechizo a partir del nombre (WowFHechizos de tu clase o de cualquier clase)
local function idPorNombre(nombre, clase)
  if type(nombre) ~= "string" or not WowFHechizos then return nil end
  if not clase and UnitClass then local ok, _, c = pcall(UnitClass, "player"); if ok then clase = c end end
  local h = clase and WowFHechizos[clase] and WowFHechizos[clase][nombre]
  if type(h) == "table" and h[2] then return h[2] end
  for _, l in pairs(WowFHechizos) do
    local x = type(l) == "table" and l[nombre]
    if type(x) == "table" and x[2] then return x[2] end
  end
  return nil
end
WowF.idHechizo = idPorNombre

-- icono de un talento por nombre (campo 6 de WowFDatos.clases[CLASE].talentos)
local function iconoTalento(nombre, clase)
  if type(nombre) ~= "string" or not WowFDatos or not WowFDatos.clases then return nil end
  if not clase and UnitClass then local ok, _, c = pcall(UnitClass, "player"); if ok then clase = c end end
  local cl = clase and WowFDatos.clases[clase]
  local t = cl and cl.talentos and cl.talentos[nombre]
  if type(t) == "table" and type(t[6]) == "string" and t[6] ~= "" then return t[6] end
  return nil
end

-- WowF.iconoHechizo(id o nombre [, clase]) -> textura (ruta o fileDataID) o nil
function WowF.iconoHechizo(x, clase)
  local id = tonumber(x)
  if not id and type(x) == "string" then
    local ic = iconoTalento(x, clase)
    if ic then return ruta(ic) end
    id = idPorNombre(x, clase)
  end
  if not id then return nil end
  local dato = WowFIconos and WowFIconos[id]
  if dato then return ruta(dato) end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    t = ok and WowF.texturaBuena and WowF.texturaBuena(t)
    if t then return t end
  end
  if GetSpellTexture then
    local ok, t = pcall(GetSpellTexture, id)
    t = ok and WowF.texturaBuena and WowF.texturaBuena(t)
    if t then return t end
  end
  return nil
end

-- textura valida del cliente: no secreta, no vacia y no el signo de interrogacion (134400 = INV_Misc_QuestionMark,
-- lo que da el cliente si aun no conoce el objeto)
local QM_ID = 134400
local function buena(t)
  if t == nil then return nil end
  if issecretvalue then
    local ok, s = pcall(issecretvalue, t)
    if not ok or s then return nil end
  end
  if type(t) == "number" then
    if t <= 0 or t == QM_ID then return nil end
    return t
  end
  if type(t) == "string" then
    if t == "" or t:lower():find("questionmark", 1, true) then return nil end
    return t
  end
  return nil
end
WowF.texturaBuena = buena

-- WowF.iconoObjeto(itemId [, respaldo]) -> textura o nil. Orden (12-oct): 1) el cliente, por el id del PROPIO objeto
-- (C_Item.GetItemIconByID, GetItemIcon, GetItemInfoInstant); 2) el respaldo que pasa quien llama (icono de los datos
-- de ese mismo objeto); 3) WowFDatos.obj[id][3]; 4) nil (quien llama decide su reserva).
function WowF.iconoObjeto(id, respaldo)
  id = tonumber(id)
  if id then
    if C_Item and C_Item.GetItemIconByID then
      local ok, t = pcall(C_Item.GetItemIconByID, id)
      t = ok and buena(t)
      if t then return t end
    end
    if GetItemIcon then
      local ok, t = pcall(GetItemIcon, id)
      t = ok and buena(t)
      if t then return t end
    end
    if GetItemInfoInstant then
      local ok, t = pcall(function() return (select(5, GetItemInfoInstant(id))) end)
      t = ok and buena(t)
      if t then return t end
    end
  end
  local r = buena(respaldo) and ruta(respaldo)
  if r then return r end
  local o = id and WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
  if type(o) == "table" and type(o[3]) == "string" and o[3] ~= "" then return ruta(o[3]) end
  return nil
end
