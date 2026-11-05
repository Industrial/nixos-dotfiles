-- wowF Retratos: retrato redondo del NPC (como el Dungeon Journal) para vendedor, entrenadores, misiones, lineas, ruta y jefes.
--   WowF.retrato(tex, opts)       pinta un retrato redondo en una Texture.
--     opts = { unidad = "npc"|"target"|..., npc = npcId, display = displayId, cara = fileDataID, icono = respaldo }
--     extra: nombre = nombre del NPC (cuando los datos no traen su id: lineas de misiones), coords = {l,r,t,b} del icono.
--     Prioridad: unidad visible -> display aprendido (WowFExportarDB.retratos[npc]) -> cara (UI-EJ-BOSS) -> display de los datos -> icono.
--   WowF.marcoRetrato(padre, tam) Frame redondo con borde hibrido (oro + piedra), campo .tex y :poner(opts) / :resaltar(si).
--   WowF.aprenderRetrato(unidad)  guarda el displayId del NPC que tienes delante (lo llaman solos los eventos).
--   WowF.retratoDisplay(npc)      displayId aprendido de ese NPC, o nil.
-- El cliente NO trae el mapa npcId -> displayId: se aprende cuando el NPC esta delante (MERCHANT_SHOW, GOSSIP_SHOW,
-- QUEST_DETAIL, TRAINER_SHOW, target) con un PlayerModel oculto, y se repinta con PORTRAITS_UPDATED.
-- Todo con pcall y sin valores secretos: si la API no esta, cae a cara o icono sin romper.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}

local MASCARA = "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- 130924
local ICONO_VACIO = "Interface\\Icons\\INV_Misc_QuestionMark"
local TOPE_CACHE = 400 -- NPC recordados como mucho

local function secreto(v) return issecretvalue and issecretvalue(v) end
local function cache()
  if type(WowFExportarDB.retratos) ~= "table" then WowFExportarDB.retratos = {} end
  return WowFExportarDB.retratos
end

-- npcId de una unidad (GUID Creature-0-...-<npc>-...), nil si es jugador o no se puede leer
local function npcDe(unidad)
  if not unidad or not UnitGUID then return nil end
  local ok, g = pcall(UnitGUID, unidad)
  if not ok or type(g) ~= "string" or secreto(g) then return nil end
  local tipo, id = g:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if tipo == "Creature" or tipo == "Vehicle" then return tonumber(id) end
  return nil
end
WowF.npcDeUnidad = WowF.npcDeUnidad or npcDe

local function nombreDe(unidad)
  if not unidad or not UnitName then return nil end
  local ok, n = pcall(UnitName, unidad)
  if not ok or type(n) ~= "string" or secreto(n) or n == "" then return nil end
  return n
end

local function existe(unidad)
  if not unidad or not UnitExists then return false end
  local ok, si = pcall(UnitExists, unidad)
  return ok and si and not secreto(si) and true or false
end

-- ----- Pintar -----
local vivos = setmetatable({}, { __mode = "k" }) -- tex -> opts, para repintar con PORTRAITS_UPDATED o al aprender

local function enmascarar(tex)
  if tex._wowfMascara ~= nil then return end
  tex._wowfMascara = false
  local padre = tex.GetParent and tex:GetParent()
  if not padre or not padre.CreateMaskTexture then return end
  local ok, m = pcall(padre.CreateMaskTexture, padre)
  if not ok or not m then return end
  pcall(m.SetTexture, m, MASCARA, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  pcall(m.SetAllPoints, m, tex)
  if pcall(tex.AddMaskTexture, tex, m) then tex._wowfMascara = m end
end

-- 11-oct: con mascara el cliente puede negar SetTexCoord ("Cannot set tex coords when texture has mask")
local function coordenadas(tex, a, b, c, d) if tex.SetTexCoord then pcall(tex.SetTexCoord, tex, a, b, c, d) end end

local function conDisplay(tex, d)
  if not d or not SetPortraitTextureFromCreatureDisplayID then return false end
  coordenadas(tex, 0, 1, 0, 1)
  return (pcall(SetPortraitTextureFromCreatureDisplayID, tex, d))
end

local aprender -- adelante

local function pintar(tex, o)
  local unidad = o.unidad
  -- 1. La unidad que tienes delante (si se pidio un npc concreto, tiene que ser ese)
  if unidad and existe(unidad) and SetPortraitTexture then
    local n = npcDe(unidad)
    local vale = (not o.npc or n == o.npc) and (not o.nombre or nombreDe(unidad) == o.nombre)
    if vale then -- con npc o nombre pedido, la unidad tiene que ser ese NPC (nunca otro objetivo cualquiera)
      coordenadas(tex, 0, 1, 0, 1)
      if pcall(SetPortraitTexture, tex, unidad) then
        if n then pcall(aprender, unidad) end
        return "unidad"
      end
    end
  end
  -- 2. El display aprendido delante del NPC
  local d = (o.npc and cache()[o.npc]) or (o.nombre and cache()["n:" .. o.nombre])
  if conDisplay(tex, d) then return "display" end
  -- 3. La cara del Dungeon Journal (128x64: se recorta a la cara): el retrato oficial manda sobre el display de los datos
  if o.cara then
    tex:SetTexture(o.cara)
    coordenadas(tex, 0.15, 0.65, 0, 1)
    return "cara"
  end
  -- 3b. 12-oct: display de los datos (jefes sin cara: Journal de la beta o Wowhead /forever)
  if conDisplay(tex, o.display) then return "display" end
  -- 4. Icono de respaldo
  tex:SetTexture(o.icono or ICONO_VACIO)
  if o.coords then coordenadas(tex, o.coords[1], o.coords[2], o.coords[3], o.coords[4])
  else coordenadas(tex, 0.08, 0.92, 0.08, 0.92) end
  return "icono"
end

function WowF.retrato(tex, opts)
  if not tex then return nil end
  if not opts then vivos[tex] = nil; return nil end
  enmascarar(tex)
  vivos[tex] = opts
  local ok, como = pcall(pintar, tex, opts)
  if not ok then
    pcall(tex.SetTexture, tex, opts.icono or ICONO_VACIO)
    return "icono"
  end
  tex._wowfComo = como
  return como
end

local function repintar(npc, nombre)
  for tex, o in pairs(vivos) do
    if not npc or o.npc == npc or (nombre and o.nombre == nombre) or o.unidad then
      local visible = true
      pcall(function() visible = tex:IsVisible() end)
      if visible then pcall(pintar, tex, o) end
    end
  end
end
WowF.repintarRetratos = function() repintar(nil) end

-- ----- Aprender el displayId con un PlayerModel oculto -----
local modelo, aprendiendo, aprendiendoNombre
local function guardar(npc, d, nombre)
  if not npc or type(d) ~= "number" or secreto(d) or d <= 0 then return end
  local c = cache()
  if nombre then c["n:" .. nombre] = d end
  if c[npc] == d then return end
  if not c[npc] then
    local n = 0
    for _ in pairs(c) do n = n + 1 end
    if n >= TOPE_CACHE then for k in pairs(c) do c[k] = nil; break end end
  end
  c[npc] = d
  repintar(npc, nombre)
end
local function leerModelo()
  if not modelo or not aprendiendo or not modelo.GetDisplayInfo then return end
  local ok, d = pcall(modelo.GetDisplayInfo, modelo)
  if ok and type(d) == "number" and not secreto(d) and d > 0 then
    guardar(aprendiendo, d, aprendiendoNombre)
    aprendiendo, aprendiendoNombre = nil, nil
    pcall(modelo.ClearModel, modelo)
  end
end
local function crearModelo()
  if modelo ~= nil then return modelo end
  modelo = false
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
  if not ok or not m then return modelo end
  m:SetSize(2, 2)
  m:SetPoint("BOTTOMLEFT", UIParent, "TOPRIGHT", 50, 50) -- fuera de la pantalla, pero "mostrado" para que cargue
  pcall(m.SetAlpha, m, 0)
  pcall(m.SetScript, m, "OnModelLoaded", leerModelo)
  m:Show()
  modelo = m
  return modelo
end
aprender = function(unidad)
  local npc = npcDe(unidad)
  if not npc then return nil end
  local nombre = nombreDe(unidad)
  if cache()[npc] then
    if nombre then cache()["n:" .. nombre] = cache()[npc] end
    return cache()[npc]
  end
  local m = crearModelo()
  if not m or not m.SetUnit then return nil end
  aprendiendo, aprendiendoNombre = npc, nombre
  if pcall(m.SetUnit, m, unidad) then leerModelo() end
  return cache()[npc]
end
WowF.aprenderRetrato = function(unidad) local ok, d = pcall(aprender, unidad or "npc"); return ok and d or nil end
WowF.retratoDisplay = function(npc) return npc and cache()[type(npc) == "string" and ("n:" .. npc) or npc] or nil end -- id o nombre

-- ----- Marco redondo con borde hibrido -----
local function color(nombre, r, g, b)
  local E = WowF.estilo
  local c = E and E.color and E.color[nombre]
  if c then return c[1], c[2], c[3] end
  return r, g, b
end
local function disco(padre, capa, sub, nombre, r, g, b)
  local t = padre:CreateTexture(nil, capa, nil, sub)
  t:SetColorTexture(color(nombre, r, g, b))
  enmascarar(t)
  return t
end
function WowF.marcoRetrato(padre, tam)
  tam = tam or 32
  local f = CreateFrame("Frame", nil, padre)
  f:SetSize(tam, tam)
  local borde = tam >= 36 and 2 or 1
  f.aro = disco(f, "BACKGROUND", 1, "oro2", 0.62, 0.48, 0.2)
  f.aro:SetAllPoints()
  f.fondo = disco(f, "BACKGROUND", 2, "piedra", 0.1, 0.09, 0.08)
  f.fondo:SetPoint("TOPLEFT", borde, -borde); f.fondo:SetPoint("BOTTOMRIGHT", -borde, borde)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", borde + 1, -borde - 1); f.tex:SetPoint("BOTTOMRIGHT", -borde - 1, borde + 1)
  function f:poner(opts)
    self.opts = opts
    return WowF.retrato(self.tex, opts)
  end
  function f:resaltar(si)
    if si then self.aro:SetColorTexture(color("brasa", 0.9, 0.45, 0.15))
    else self.aro:SetColorTexture(color("oro2", 0.62, 0.48, 0.2)) end
  end
  return f
end

-- ----- Eventos: aprender delante del NPC y repintar -----
local ev = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_GREETING", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "TRAINER_SHOW", "PLAYER_TARGET_CHANGED", "PORTRAITS_UPDATED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  if evento == "PORTRAITS_UPDATED" then pcall(repintar, nil); return end
  if evento == "PLAYER_TARGET_CHANGED" then
    if existe("target") then pcall(aprender, "target") end
    return
  end
  pcall(aprender, "npc")
end)
