-- Forever Leveling Guide: aviso de mision de grupo / elite (5-oct-2026).
-- Al leer una mision (QUEST_DETAIL) mira lo que el propio juego dice de ella, sin datos de fuera:
--   GetSuggestedGroupNum() (jugadores sugeridos), C_QuestLog.GetQuestTagInfo(id) (tagID 1 = Group, 81 = Dungeon, 62 = Raid,
--   isElite) o el GetQuestTagInfo clasico. Si es de grupo, cartel junto a la ventana de la mision:
--   "Mision de grupo (N jugadores): no la hagas solo, busca grupo."
-- En el registro de misiones, si existe el boton del titulo, la misma linea en el tooltip.
-- Si no hay ninguna de esas API, no hace nada (sin errores).
-- /wowf misiongrupo on|off (/wowf groupquest on|off) y casilla en Ajustes. Encendido por defecto.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, NARANJA, GRIS = "|cff1eff00", "|cffff8000", "|cff9d9d9d"

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
local function db()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  return WowFExportarDB
end
local function marcar(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end

function WowF.misionGrupoActiva() return db().misionGrupo ~= false end
function WowF.misionGrupoDisponible()
  return type(GetSuggestedGroupNum) == "function" or (C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function")
    or type(GetQuestTagInfo) == "function"
end

local TAG_GRUPO = { [1] = "grupo", [81] = "mazmorra", [62] = "banda", [88] = "banda", [89] = "banda" }

-- Lo que el juego dice de una mision. Devuelve tipo ("grupo"|"elite"|"mazmorra"|"banda") y jugadores (o nil), o nil si es normal.
-- sugerido = GetSuggestedGroupNum() (solo vale para la mision abierta en QUEST_DETAIL)
function WowF.misionDeGrupo(questID, sugerido)
  local tipo, jugadores
  local n = numero(sugerido)
  if n and n > 1 then tipo, jugadores = "grupo", n end
  if questID and C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function" then
    local t = llamar(C_QuestLog.GetQuestTagInfo, questID)
    if type(t) == "table" then
      local id = numero(t.tagID)
      if id and TAG_GRUPO[id] then tipo = (TAG_GRUPO[id] ~= "grupo") and TAG_GRUPO[id] or (tipo or "grupo") end
      if t.isElite == true and not tipo then tipo = "elite" end
    end
  elseif questID and type(GetQuestTagInfo) == "function" then
    local ok, id, nombre = pcall(GetQuestTagInfo, questID)
    id = ok and numero(id)
    if id and TAG_GRUPO[id] then tipo = (TAG_GRUPO[id] ~= "grupo") and TAG_GRUPO[id] or (tipo or "grupo") end
  end
  return tipo, jugadores
end

-- El texto del cartel para un tipo/jugadores
function WowF.textoMisionGrupo(tipo, jugadores)
  if not tipo then return nil end
  local j = jugadores and L(" (" .. jugadores .. " jugadores)", " (" .. jugadores .. " players)") or ""
  if tipo == "mazmorra" then return marcar(NARANJA .. L("Mision de mazmorra", "Dungeon quest") .. j .. ":|r " .. L("se hace dentro, en grupo.", "it is done inside, with a group.")) end
  if tipo == "banda" then return marcar(NARANJA .. L("Mision de banda", "Raid quest") .. j .. ":|r " .. L("no la hagas solo, busca banda.", "do not do it alone, find a raid.")) end
  if tipo == "elite" then return marcar(NARANJA .. L("Mision elite", "Elite quest") .. j .. ":|r " .. L("no la hagas solo, busca grupo.", "do not do it alone, find a group.")) end
  return marcar(NARANJA .. L("Mision de grupo", "Group quest") .. j .. ":|r " .. L("no la hagas solo, busca grupo.", "do not do it alone, find a group."))
end

-- ===================== Cartel en la ventana de la mision =====================
local cartel
local function crearCartel()
  if cartel then return cartel end
  cartel = CreateFrame("Frame", "wowFMisionGrupo", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  cartel:SetSize(260, 70)
  cartel:SetFrameStrata("DIALOG")
  -- 11-oct (hibrido): fondo de piedra, cabecera pequena "Forever Guide" y el aviso en Signika
  local E = WowF.estilo
  E.marco(cartel, "aviso")
  cartel.cab = E.cabecera(cartel, 18)
  cartel.cab.titulo:SetText("Forever Guide")
  cartel.texto = E.cuerpo(cartel, nil, 12)
  cartel.texto:SetPoint("TOPLEFT", 12, -32)
  cartel.texto:SetWidth(236)
  cartel.texto:SetJustifyH("LEFT")
  cartel:Hide()
  return cartel
end

local ultimo
function WowF.mostrarMisionGrupo()
  if not WowF.misionGrupoActiva() then ultimo = nil; if cartel then cartel:Hide() end return nil end
  local id = numero(llamar(GetQuestID))
  local tipo, jug = WowF.misionDeGrupo(id, llamar(GetSuggestedGroupNum))
  local t = WowF.textoMisionGrupo(tipo, jug)
  ultimo = t
  if not t then if cartel then cartel:Hide() end return nil end
  local c = crearCartel()
  c.texto:SetText(t)
  c:SetHeight(math.max(60, math.floor(32 + (numero(llamar(c.texto.GetStringHeight, c.texto)) or 28) + 12)))
  c:ClearAllPoints()
  local padre = _G.QuestFrame
  -- 5-oct (revision): encima de la ventana de la mision ya va el cartel morado de wowF_MisionesMazmorra
  -- ("cogela ANTES de entrar"); este va a la DERECHA de la ventana para no taparlo
  if padre and padre.IsShown and padre:IsShown() then c:SetPoint("TOPLEFT", padre, "TOPRIGHT", 4, 0)
  else c:SetPoint("TOP", UIParent, "TOP", 0, -120) end
  c:Show()
  return t
end
WowF.misionGrupoUltimo = function() return ultimo end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_FINISHED", "QUEST_ACCEPTED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  if evento == "QUEST_DETAIL" then pcall(WowF.mostrarMisionGrupo)
  elseif cartel then cartel:Hide() end
end)

-- ===================== Tooltip del registro de misiones =====================
-- Linea extra al pasar el raton por el titulo (si el cliente tiene esos botones)
function WowF.misionGrupoTooltip(boton)
  if not WowF.misionGrupoActiva() or not GameTooltip then return nil end
  local id = type(boton) == "table" and numero(boton.questID)
  if not id then return nil end
  local t = WowF.textoMisionGrupo(WowF.misionDeGrupo(id, nil))
  if t and GameTooltip.IsShown and GameTooltip:IsShown() then
    GameTooltip:AddLine(t, 1, 1, 1, true)
    GameTooltip:Show()
  end
  return t
end
local enganchado = false
local function engancharTooltip()
  if enganchado or type(hooksecurefunc) ~= "function" then return end
  for _, nombre in ipairs({ "QuestMapLogTitleButton_OnEnter", "QuestLogTitleButton_OnEnter" }) do
    if type(_G[nombre]) == "function" then
      pcall(hooksecurefunc, nombre, function(b) pcall(WowF.misionGrupoTooltip, b) end)
      enganchado = true
    end
  end
end
engancharTooltip()
local ev2 = CreateFrame("Frame")
pcall(ev2.RegisterEvent, ev2, "PLAYER_LOGIN")
pcall(ev2.RegisterEvent, ev2, "ADDON_LOADED")
ev2:SetScript("OnEvent", function() engancharTooltip() end)

-- Casilla en Ajustes (wowF_Opciones.lua)
if WowF.registrarCasillaOpciones then WowF.registrarCasillaOpciones("misionGrupo", function() return L("Avisarme de las misiones de grupo", "Alert me about group quests") end) end

-- ===================== /wowf misiongrupo =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "misiongrupo" or orden == "groupquest" then
    local t = db()
    if resto == "off" or resto == "no" then t.misionGrupo = false elseif resto == "on" or resto == "si" then t.misionGrupo = true
    else t.misionGrupo = not WowF.misionGrupoActiva() end
    if not WowF.misionGrupoActiva() and cartel then cartel:Hide() end
    local extra = ""
    if not WowF.misionGrupoDisponible() then extra = GRIS .. L(" (este cliente no dice que misiones son de grupo: no hara nada)", " (this client does not tell which quests are group quests: it will do nothing)") .. "|r" end
    print(PREFIJO .. L("aviso de mision de grupo ", "group quest alert ") .. (WowF.misionGrupoActiva() and (VERDE .. L("ENCENDIDO", "ON")) or (GRIS .. L("APAGADO", "OFF"))) .. "|r" ..
      extra .. L(". /wowf misiongrupo on|off", ". /wowf groupquest on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
