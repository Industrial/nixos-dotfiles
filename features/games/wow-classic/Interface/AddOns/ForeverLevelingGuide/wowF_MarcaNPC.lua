-- wowF Marca del NPC (6-oct, Andy: un amigo dice que "al llegar se desaparece todo y no marca quien es el personaje").
-- Una sola marca, bien visible, sobre el NPC con el que tienes que hablar AHORA:
--   * mision de mazmorra que se coge FUERA (clic en el mapa, Libro o panel: wowF_MisionesMazmorra.irAMision);
--   * misiones que se cogen DENTRO de la mazmorra (al estar dentro, las de tu nivel que aun no tienes);
--   * linea de misiones: el NPC del paso que toca (wowF_LineaMisiones, WowF._lineaNPC);
--   * mision que da una pieza de Equipo (wowF_EquipoGuia).
-- Donde: en la esquina de arriba a la derecha del nombre (o de la barra de vida) de su placa: el ! de mision grande,
-- con un brillo dorado que late, "HABLA AQUI" y debajo para que es (linea k/T, mazmorra, pieza).
-- Se reconoce por el id del NPC (del GUID: vale con el juego en cualquier idioma) y, si no hay id, por su nombre.
-- La marca SIGUE al llegar (la ruta se quita, la marca no) hasta que aceptas o entregas la mision.
-- Mientras haya marca se encienden las placas de NPC amistosos (vuelven como estaban al quitarla).
-- (6-oct: sin estrella de banda: SetRaidTarget esta reservado a Blizzard en este cliente)
-- /wowf marca off|on: apaga o enciende la marca.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, MORADO = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffc77dff"
local NARANJA = "|cffff9933"
local ICONO = "Interface\\GossipFrame\\AvailableQuestIcon"
local BRILLO = "Interface\\Cooldown\\star4"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function seguro(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function apagada() return WowFExportarDB.marcaNPCOff == true end
local function nivelActual()
  local ok, n = pcall(UnitLevel, "player")
  n = ok and seguro(n)
  return tonumber(n) or 1
end
local function hecha(id)
  if WowF.misionHecha then return WowF.misionHecha(id) end
  if not id or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then return false end
  local ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
  return ok and seguro(r) == true
end
local function enElDiario(id)
  if not id then return false end
  local ok, r
  if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then ok, r = pcall(C_QuestLog.GetLogIndexForQuestID, id)
  elseif type(GetQuestLogIndexByID) == "function" then ok, r = pcall(GetQuestLogIndexByID, id) end
  r = ok and seguro(r)
  return type(r) == "number" and r > 0
end
local function enInstancia()
  if type(IsInInstance) ~= "function" then return false end
  local ok, dentro, tipo = pcall(IsInInstance)
  return ok and seguro(dentro) == true and (seguro(tipo) == "party" or seguro(tipo) == "raid" or seguro(tipo) == nil)
end
local function enGrupo()
  local ok, r = pcall(IsInGroup)
  return ok and seguro(r) == true
end
local function limpio(n) if type(n) ~= "string" then return nil end return (n:gsub("^%s+", ""):gsub("%s+$", "")) end
local function nombreUnidad(u)
  local ok, n = pcall(UnitName, u)
  return limpio(ok and seguro(n) or nil)
end
local function npcDe(u)
  local ok, g = pcall(UnitGUID, u)
  g = ok and seguro(g)
  if type(g) ~= "string" then return nil end
  local tipo, id = g:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if tipo == "Creature" or tipo == "Vehicle" then return tonumber(id) end
  return nil
end

-- ----- A quien hay que marcar ahora -----
-- WowFExportarDB.marcaNPC = { n = nombre, npc = id, qid = mision, sub = "para que es", entrega = true si es para entregar, nivel = nivel que pide la mision }
local function objetivos()
  local t = {}
  if apagada() then return t end
  local g = WowFExportarDB.marcaNPC
  if type(g) == "table" and g.n then
    -- ya aceptada (o entregada): la marca sobra
    if g.qid and (hecha(g.qid) or (not g.entrega and enElDiario(g.qid))) then WowFExportarDB.marcaNPC = nil
    -- 6-oct (Rahauro a nivel 8, pide 9): si aun no te la da, la marca lo dice en vez de "HABLA AQUI"
    else
      local pide = tonumber(g.nivel)
      t[#t + 1] = { n = limpio(g.n), npc = tonumber(g.npc), sub = g.sub, entrega = g.entrega and true or nil, aunNo = (pide and nivelActual() < pide) and pide or nil }
    end
  end
  if WowF._lineaNPC then
    local ok, n, k, total = pcall(WowF._lineaNPC)
    if ok and n then t[#t + 1] = { n = limpio(n), sub = ORO .. L("LINEA " .. k .. "/" .. total, "QUESTLINE " .. k .. "/" .. total) .. "|r" } end
  end
  if enInstancia() and WowF.misionesMazmorraPendientes then
    local ok, lista = pcall(WowF.misionesMazmorraPendientes)
    local nivel = nivelActual()
    for _, q in ipairs(ok and lista or {}) do
      if q.dentro and not q.yaLaTienes and nivel >= (q.nivel or 0) and q.quien and q.quien ~= "" then
        t[#t + 1] = { n = limpio(q.quien), npc = tonumber(q.npc), sub = MORADO .. L("Mision: ", "Quest: ") .. (q.mazmorra and q.mazmorra.n or "") .. "|r" }
      end
    end
  end
  return t
end
local function objetivoDe(u)
  local lista = objetivos()
  if #lista == 0 then return nil end
  local id, n = npcDe(u), nombreUnidad(u)
  -- id 0 = lo da un objeto (Spectral Chalice, The Discs of Norgannon): no se compara por id
  for _, o in ipairs(lista) do if o.npc and o.npc > 0 and id and o.npc == id then return o end end
  for _, o in ipairs(lista) do if n and o.n == n then return o end end
  return nil
end
WowF.marcaNPCObjetivos = objetivos -- para las pruebas
WowF.marcaNPCDe = objetivoDe -- las otras marcas de placa se quitan donde va esta (no se amontonan)

-- ----- La marca en la placa -----
-- 11-oct (FLG-ERR SetPreferredGamepadInteractTarget, jugador con mando): con el mando activo el juego elige el objetivo
-- con las placas de nombre; no se cambian sus CVars ni se cuelga nada de ellas (marcos propios, solo anclados)
local function conMando() return WowF.interfazMando() end -- 22-oct: mando conectado de verdad (wowF_Estilo.lua)
-- 14-oct (FLG-ERR 4.36 SetPreferredGamepadInteractTarget, Dun Morogh, mando 1, sin combate): anclar marcos a las placas
-- tambien lo provoca. Con mando NO se pone nada sobre las placas (ninguna marca: NPC, linea, mazmorra, jefes);
-- el mapa, la ruta y los avisos siguen igual. Se avisa una vez por sesion.
local avisadoMando = false
function WowF.mandoActivo()
  if not conMando() then return false end
  if not avisadoMando then
    avisadoMando = true
    print(AZUL .. L("juegas con mando: el addon no toca las ventanas del juego (marcas sobre los NPC, dibujos en el mapa ni abrirlo) para que el juego no bloquee el mando. La flecha de destino, la ruta en el chat y los avisos siguen igual.",
      "you play with a gamepad: the addon does not touch the game windows (marks above NPCs, drawings on the map or opening it) so the game does not block the gamepad. The destination arrow, the route in chat and the alerts work the same."))
  end
  return true
end
local marcas = {}
local function latir(m, pasado)
  m.t = (m.t or 0) + (pasado or 0)
  local s = math.sin(m.t * 5)
  m.brillo:SetAlpha(0.55 + 0.45 * s)
  m.brillo:SetSize(58 + 12 * s, 58 + 12 * s)
end
local function marcaEn(placa)
  if marcas[placa] then return marcas[placa] end
  if placa.IsForbidden and placa:IsForbidden() == true then return nil end
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(30, 30)
  m:SetFrameStrata("HIGH")
  m.brillo = m:CreateTexture(nil, "BACKGROUND")
  m.brillo:SetTexture(BRILLO)
  pcall(m.brillo.SetBlendMode, m.brillo, "ADD")
  m.brillo:SetVertexColor(1, 0.85, 0.1)
  m.brillo:SetPoint("CENTER", m, "CENTER", 0, 0)
  m.brillo:SetSize(60, 60)
  m.icono = m:CreateTexture(nil, "ARTWORK")
  m.icono:SetAllPoints()
  m.icono:SetTexture(ICONO)
  m.titulo = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pcall(m.titulo.SetFont, m.titulo, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 14, "OUTLINE")
  if WowF.estilo then WowF.estilo.letra(m.titulo, "marca", 14, "OUTLINE") end -- 11-oct (hibrido): Cinzel, mismo tamano
  m.titulo:SetPoint("BOTTOMLEFT", m, "RIGHT", 1, 0)
  m.sub = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pcall(m.sub.SetFont, m.sub, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 11, "OUTLINE")
  if WowF.estilo then WowF.estilo.letra(m.sub, "boton", 11, "OUTLINE") end -- Signika, mismo tamano
  m.sub:SetPoint("TOPLEFT", m, "RIGHT", 1, -1)
  m:SetScript("OnUpdate", latir)
  marcas[placa] = m
  return m
end
-- Esquina de arriba a la derecha del nombre (o de la barra de vida); si el juego no deja verlos, de la placa
local function colocar(m, placa)
  local uf = placa.UnitFrame
  local ancla = placa
  if type(uf) == "table" then
    for _, k in ipairs({ "name", "healthBar", "HealthBarsContainer" }) do
      local x = uf[k]
      if type(x) == "table" and x.IsShown then local ok, v = pcall(x.IsShown, x); if ok and v then ancla = x; break end end
    end
  end
  m:ClearAllPoints()
  if not pcall(m.SetPoint, m, "CENTER", ancla, "TOPRIGHT", 6, 6) then m:SetPoint("CENTER", placa, "TOPRIGHT", 6, 6) end
end
-- 6-oct: SetRaidTarget esta reservado a Blizzard en este cliente (sale "blocked from an action only available to the Blizzard UI"): no se usa
local function estrella(u) end
local function revisarPlaca(u)
  local o = objetivoDe(u)
  if o then pcall(estrella, u) end
  if WowF.mandoActivo() then for _, mm in pairs(marcas) do mm:Hide() end; return o ~= nil end
  local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(u)
  if not placa then return o ~= nil end
  local m = marcas[placa]
  if not o then if m then m:Hide() end; return false end
  m = marcaEn(placa)
  if not m then return false end
  colocar(m, placa)
  if o.aunNo then
    m.titulo:SetText(NARANJA .. L("AUN NO: nivel " .. o.aunNo, "NOT YET: level " .. o.aunNo) .. "|r")
    m.sub:SetText(NARANJA .. L("eres nivel " .. nivelActual() .. "; vuelve al " .. o.aunNo, "you are level " .. nivelActual() .. "; come back at " .. o.aunNo) .. "|r")
  else
    -- 15-oct (Andy): si vas a ENTREGAR, la marca lo dice
    if o.entrega then m.titulo:SetText(VERDE .. L("ENTREGA AQUI", "TURN IN HERE") .. "|r")
    else m.titulo:SetText(VERDE .. L("HABLA AQUI", "TALK HERE") .. "|r") end
    m.sub:SetText(o.sub or "")
  end
  m:Show()
  return true
end
local function revisarPlacas()
  for _, m in pairs(marcas) do m:Hide() end
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  for _, placa in pairs(C_NamePlate.GetNamePlates() or {}) do
    if placa.namePlateUnitToken then pcall(revisarPlaca, placa.namePlateUnitToken) end
  end
end
WowF._marcaNPCPlaca = revisarPlaca -- para las pruebas

-- ----- Placas de NPC amistosos: encendidas mientras haya a quien marcar; luego como estaban -----
local function cvar(n) local ok, v = pcall(GetCVar, n); return ok and v or nil end
local function placas()
  if not SetCVar then return end
  if InCombatLockdown and InCombatLockdown() then return end -- en combate el juego lo bloquea
  -- de la 4.4: lo que guardo la linea de misiones pasa aqui
  if WowFExportarDB.placasLinea and not WowFExportarDB.placasMarca then WowFExportarDB.placasMarca = WowFExportarDB.placasLinea end
  WowFExportarDB.placasLinea = nil
  local g = WowFExportarDB.placasMarca
  if #objetivos() > 0 then
    if conMando() then return end
    if g or cvar("nameplateShowFriendlyNPCs") == "1" then return end
    WowFExportarDB.placasMarca = { amigos = cvar("nameplateShowFriends") or "0", npc = cvar("nameplateShowFriendlyNPCs") or "0" }
    pcall(SetCVar, "nameplateShowFriends", "1")
    pcall(SetCVar, "nameplateShowFriendlyNPCs", "1")
    print(AZUL .. L("encendi los nombres de los NPC amistosos para marcar a quien tienes que hablar (! dorado que late y \"HABLA AQUI\"). Vuelven como estaban al terminar.",
      "I turned on friendly NPC nameplates to mark who you have to talk to (pulsing gold ! and \"TALK HERE\"). They go back as they were when you are done."))
  elseif g then
    pcall(SetCVar, "nameplateShowFriendlyNPCs", g.npc or "0")
    pcall(SetCVar, "nameplateShowFriends", g.amigos or "0")
    WowFExportarDB.placasMarca = nil
  end
end
local function refrescar()
  pcall(placas)
  pcall(revisarPlacas)
end
WowF.marcaNPCRefrescar = refrescar

-- ----- Lo que usan los demas -----
-- d = { n = nombre del NPC, npc = id, qid = id de la mision, sub = "para que es", entrega = true si vas a entregarla }
function WowF.marcarNPC(d)
  if type(d) ~= "table" or not d.n or d.n == "" or d.n == "?" then return false end
  WowFExportarDB.marcaNPC = { n = d.n, npc = d.npc, qid = d.qid, sub = d.sub, entrega = d.entrega, nivel = tonumber(d.nivel) }
  refrescar()
  return true
end
function WowF.quitarMarcaNPC()
  if not WowFExportarDB.marcaNPC then return end
  WowFExportarDB.marcaNPC = nil
  refrescar()
end
-- Al llegar al NPC (wowF_Viaje): aviso grande en el centro de la pantalla
function WowF.avisoLlegadaNPC(nombre)
  if apagada() or not nombre then return end
  local g = WowFExportarDB.marcaNPC
  local pide = type(g) == "table" and limpio(g.n) == limpio(nombre) and tonumber(g.nivel)
  if pide and nivelActual() < pide then
    local t2 = L(nombre .. " AUN NO te da la mision: pide nivel " .. pide .. " y eres nivel " .. nivelActual() .. ". Vuelve al subir.",
      nombre .. " will NOT give you the quest yet: it needs level " .. pide .. " and you are level " .. nivelActual() .. ". Come back when you level up.")
    local ok2 = RaidNotice_AddMessage and RaidWarningFrame and pcall(RaidNotice_AddMessage, RaidWarningFrame, t2, { r = 1, g = 0.6, b = 0.2 })
    if not ok2 and UIErrorsFrame and UIErrorsFrame.AddMessage then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, t2, 1, 0.6, 0.2) end
    return
  end
  local t = L("Habla con " .. nombre .. ": tiene el ! dorado que late y \"HABLA AQUI\" junto a su nombre",
    "Talk to " .. nombre .. ": the pulsing gold ! and \"TALK HERE\" are next to the name")
  if type(g) == "table" and g.entrega and limpio(g.n) == limpio(nombre) then
    t = L("Entrega la mision a " .. nombre .. ": tiene el ! dorado que late y \"ENTREGA AQUI\" junto a su nombre",
      "Turn the quest in to " .. nombre .. ": the pulsing gold ! and \"TURN IN HERE\" are next to the name")
  end
  local ok = RaidNotice_AddMessage and RaidWarningFrame and pcall(RaidNotice_AddMessage, RaidWarningFrame, t, { r = 0.2, g = 1, b = 0.4 })
  if not ok and UIErrorsFrame and UIErrorsFrame.AddMessage then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, t, 0.2, 1, 0.4) end
end

local vigia = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP",
  "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED" }) do pcall(vigia.RegisterEvent, vigia, e) end
vigia:SetScript("OnEvent", function(_, evento, a, b)
  if evento == "NAME_PLATE_UNIT_ADDED" then pcall(revisarPlaca, a); return end
  if evento == "NAME_PLATE_UNIT_REMOVED" then
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(a)
    if placa and marcas[placa] then marcas[placa]:Hide() end
    return
  end
  if evento == "UPDATE_MOUSEOVER_UNIT" then if objetivoDe("mouseover") then pcall(estrella, "mouseover") end; return end
  if evento == "PLAYER_TARGET_CHANGED" then if objetivoDe("target") then pcall(estrella, "target") end; return end
  if evento == "QUEST_ACCEPTED" or evento == "QUEST_TURNED_IN" then
    -- QUEST_ACCEPTED: (indice, id) en el cliente clasico, (id) en el moderno; QUEST_TURNED_IN: (id, xp, dinero)
    local id = a
    if evento == "QUEST_ACCEPTED" and b and type(b) == "number" and b > 0 then id = b end
    id = tonumber(seguro(id))
    local g = WowFExportarDB.marcaNPC
    if type(g) == "table" and id and g.qid == id and (evento == "QUEST_TURNED_IN" or not g.entrega) then WowFExportarDB.marcaNPC = nil end
  end
  refrescar()
end)

-- /wowf marca off|on
local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "marca" or orden == "mark" then
    if resto == "off" or resto == "no" then WowFExportarDB.marcaNPCOff = true; refrescar(); print(AZUL .. L("marca sobre el NPC: apagada (/wowf marca on para verla).", "NPC mark: off (/wowf mark on to show it)."))
    else WowFExportarDB.marcaNPCOff = nil; refrescar(); print(AZUL .. L("marca sobre el NPC: encendida.", "NPC mark: on.")) end
    return
  end
  if anterior then return anterior(mensaje) end
end
