-- Forever Leveling Guide: costo del entrenador de clase (5-oct-2026).
-- No hay datos verificados de lo que cuesta cada hechizo en Forever, asi que NO se inventa ningun precio:
--   * Al abrir el entrenador de clase (TRAINER_SHOW) se suma el costo REAL de lo que puedes aprender ahora
--     (GetTrainerServiceCost) y se compara con tu dinero (GetMoney): "Te alcanza" o "Te faltan Xg".
--   * Los costos que el juego te enseña se guardan (WowFExportarDB.costosEntrenador[CLASE]["Nombre Rango"]) y se usan en el
--     aviso al subir de nivel (WowF.lineaCostoEntrenar, desde wowF_AvisosNuevos.lua). Si aun no se conocen, se dice que
--     el costo aparece al abrir el entrenador.
--   * Nada de "salta este rango": ninguna fuente lo respalda.
-- Si falta alguna API del entrenador, la funcion se apaga sola sin errores.
-- /wowf entrenamiento on|off (/wowf training on|off) y casilla en Ajustes. Encendido por defecto.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local VERDE, ORO, ROJO, GRIS, BLANCO = "|cff1eff00", "|cffffd100", "|cffff6060", "|cff9d9d9d", "|cffffffff"

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
  c = math.floor(c or 0)
  local g, s, co = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "g" end
  if s > 0 then t[#t + 1] = s .. "s" end
  if co > 0 or #t == 0 then t[#t + 1] = co .. "c" end
  return table.concat(t, " ")
end
local function claseJugador()
  local ok, _, token = pcall(UnitClass, "player")
  if ok and texto(token) then return token end
  return nil
end
local function marcar(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end

function WowF.entrenamientoActivo() return db().entrenamiento ~= false end
-- Las API que hacen falta para leer el entrenador
function WowF.entrenamientoDisponible()
  return type(GetNumTrainerServices) == "function" and type(GetTrainerServiceInfo) == "function"
    and type(GetTrainerServiceCost) == "function" and type(GetMoney) == "function"
end

-- "Nombre Rango" (la clave con la que se guarda el costo)
local function clave(nombre, rango)
  if rango and rango ~= "" then return nombre .. " " .. rango end
  return nombre
end

-- 5-oct (revision): los costos se guardan tambien por el id del hechizo (guardados[spellId] = costo; el nombre depende del
-- idioma del cliente, el id no). El id sale de GetTrainerServiceSpellID o de C_TooltipInfo.GetTrainerService (si el cliente
-- los tiene). La clave "Nombre Rango" se mantiene como reserva.
local function idServicio(i)
  local id = numero(llamar(GetTrainerServiceSpellID, i))
  if not id and type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetTrainerService) == "function" then
    local ok, d = pcall(C_TooltipInfo.GetTrainerService, i)
    if ok and type(d) == "table" then id = numero(d.id) end
  end
  return id
end
-- Hechizos de tu clase (wowF_Hechizos.lua): { nombres = {Nombre = true}, ids = {spellId = Nombre} } o nil si no hay datos
local indices = {}
local function hechizosDe(token)
  if not token or type(WowFHechizos) ~= "table" or type(WowFHechizos[token]) ~= "table" then return nil end
  if indices.fuente ~= WowFHechizos then indices = { fuente = WowFHechizos } end -- datos recargados: indice nuevo
  if indices[token] then return indices[token] end
  local x = { nombres = {}, ids = {} }
  for nom, d in pairs(WowFHechizos[token]) do
    x.nombres[nom] = true
    if type(d) == "table" then for k = 2, #d do if type(d[k]) == "number" then x.ids[d[k]] = nom end end end
  end
  indices[token] = x
  return x
end
WowF._hechizosDeClase = hechizosDe

-- Lee el entrenador abierto. Devuelve { total, n, lista = {{nombre, rango, costo, id}}, sinCosto } o nil (no se pudo / de profesion /
-- no es el entrenador de TU clase)
-- 5-oct (revision): solo cuenta el entrenador de tu clase. Un entrenador sin NINGUN hechizo de tu clase (Weapon Master, entrenador
-- de mascotas, el de otra clase) no se suma ni se guarda. Sin datos de hechizos (wowF_Hechizos.lua) se lee como antes.
function WowF.leerEntrenador()
  if not WowF.entrenamientoDisponible() then return nil end
  if type(IsTradeskillTrainer) == "function" and llamar(IsTradeskillTrainer) then return nil end -- entrenador de profesion: no es esto
  local n = numero(llamar(GetNumTrainerServices)) or 0
  local r = { total = 0, n = 0, lista = {}, sinCosto = 0 }
  local token = claseJugador()
  local mios = hechizosDe(token)
  local servicios, deMiClase = {}, 0
  for i = 1, n do
    local ok, nombre, rango, categoria = pcall(GetTrainerServiceInfo, i)
    nombre, rango, categoria = ok and texto(nombre), ok and texto(rango), ok and texto(categoria)
    if nombre and categoria ~= "header" then
      local id = idServicio(i)
      if mios and ((id and mios.ids[id]) or mios.nombres[nombre]) then deMiClase = deMiClase + 1 end
      servicios[#servicios + 1] = { nombre = nombre, rango = rango, categoria = categoria, id = id, costo = numero(llamar(GetTrainerServiceCost, i)) }
    end
  end
  if mios and #servicios > 0 and deMiClase == 0 then return nil end
  local guardados
  if token then
    local t = db()
    if type(t.costosEntrenador) ~= "table" then t.costosEntrenador = {} end
    if type(t.costosEntrenador[token]) ~= "table" then t.costosEntrenador[token] = {} end
    guardados = t.costosEntrenador[token]
  end
  for _, s in ipairs(servicios) do
    local costo = s.costo
    if costo and guardados and s.categoria ~= "used" then
      guardados[clave(s.nombre, s.rango)] = costo
      if s.id then guardados[s.id] = costo end
    end
    if s.categoria == "available" then
      r.n = r.n + 1
      if costo then r.total = r.total + costo else r.sinCosto = r.sinCosto + 1 end
      r.lista[#r.lista + 1] = { nombre = s.nombre, rango = s.rango, costo = costo, id = s.id }
    end
  end
  return r
end

-- Texto "Te alcanza" / "Te faltan Xg" para un total en cobre (nil si no se puede leer tu dinero)
local function alcance(total)
  local oro = numero(llamar(GetMoney))
  if not oro then return nil end
  if oro >= total then return VERDE .. L("Te alcanza", "You can afford it") .. "|r" .. GRIS .. L(" (tienes ", " (you have ") .. dinero(oro) .. ")|r" end
  return ROJO .. L("Te faltan ", "You are short ") .. dinero(total - oro) .. "|r" .. GRIS .. L(" (tienes ", " (you have ") .. dinero(oro) .. ")|r"
end

-- ===================== Costo de lo que aprendes a cada nivel (15-oct) =====================
-- Un amigo de Andy vio "10 oro" al subir de nivel y el entrenador le cobro 10 de plata: el aviso tomaba el costo del rango
-- MAS ALTO que habia visto en el entrenador (los rangos altos se guardan como "no disponibles"), no el que aprendes ahora.
-- Ahora el costo sale de WowFCostosEntrenador (wowF_CostosEntrenador_Datos.lua, SOLO WoW Forever: Wowhead /forever,
-- trainingcost por hechizo y rango, con nivel y raza) y, si ya viste ESE rango en tu entrenador, se usa el costo real.
-- raceID del jugador como bit (1 Human, 2 Orc, 4 Dwarf, 8 Night Elf, 16 Undead, 32 Tauren, 64 Gnome, 128 Troll); nil = no se pudo leer
local function bitRaza()
  if type(UnitRace) ~= "function" then return nil end
  local ok, _, _, id = pcall(UnitRace, "player")
  id = ok and tonumber(numero(id))
  if id and id >= 1 and id <= 30 then return 2 ^ (id - 1) end
  -- razas propias de WoW Forever: Wowhead /forever las pone en los bits 32 y 33
  if id == 95 then return 2 ^ 32 end
  if id == 96 then return 2 ^ 33 end
  return nil
end
-- mascara 0 = todas las razas; raza desconocida = solo lo de todas las razas (nunca anunciar lo de otra raza)
local function razaOk(mascara, bit)
  if not mascara or mascara == 0 then return true end
  if not bit then return false end
  return math.floor(mascara / bit) % 2 == 1
end
WowF._costoRazaOk = razaOk
-- true si el hechizo (por nombre en ingles) es de otra raza segun los datos de WoW Forever (lo usa wowF_AvisosNuevos.lua)
function WowF.hechizoDeOtraRaza(nombre, token)
  token = token or claseJugador()
  local datos = token and type(WowFCostosEntrenador) == "table" and WowFCostosEntrenador[token]
  if type(datos) ~= "table" then return false end
  local bit = bitRaza()
  for _, e in pairs(datos) do
    if type(e) == "table" and e[3] == nombre and e[5] and e[5] ~= 0 then return not razaOk(e[5], bit) end
  end
  return false
end
local function conoce(id)
  if type(id) ~= "number" then return false end
  if IsPlayerSpell then local ok, s = pcall(IsPlayerSpell, id); if ok and s == true then return true end end
  if IsSpellKnown then local ok, s = pcall(IsSpellKnown, id); if ok and s == true then return true end end
  return false
end
-- Lo que tu entrenador te ensena justo a ese nivel: { total, lista = {{id, nombre, rango, costo, visto}}, vistos } o nil sin datos
function WowF.costosDelNivel(nivel, token)
  token = token or claseJugador()
  local datos = token and type(WowFCostosEntrenador) == "table" and WowFCostosEntrenador[token]
  if type(datos) ~= "table" or type(nivel) ~= "number" then return nil end
  local guardados = type(db().costosEntrenador) == "table" and db().costosEntrenador[token]
  local talentos = WowFDatos and WowFDatos.clases and WowFDatos.clases[token] and WowFDatos.clases[token].talentos
  local hechizos = type(WowFHechizos) == "table" and WowFHechizos[token]
  local bit = bitRaza()
  local r = { total = 0, lista = {}, vistos = 0 }
  for id, e in pairs(datos) do
    if type(id) == "number" and type(e) == "table" and e[1] == nivel and razaOk(e[5], bit) then
      -- rango de un talento: solo si ya tienes el talento (su rango 1)
      local esTalento = type(talentos) == "table" and talentos[e[3]]
      local h = type(hechizos) == "table" and hechizos[e[3]]
      if not esTalento or (type(h) == "table" and conoce(h[2])) then
        local real = type(guardados) == "table" and numero(guardados[id])
        local costo = real or e[2]
        r.total = r.total + costo
        if real then r.vistos = r.vistos + 1 end
        r.lista[#r.lista + 1] = { id = id, nombre = e[3], rango = e[4], costo = costo, visto = real and true or false }
      end
    end
  end
  table.sort(r.lista, function(a, b) if a.nombre ~= b.nombre then return a.nombre < b.nombre end return (a.rango or 0) < (b.rango or 0) end)
  return r
end

-- Linea para el aviso de nivel nuevo (wowF_AvisosNuevos.lua). nombres = hechizos nuevos de ese nivel.
-- Con datos de WoW Forever: suma TODO lo de ese nivel (hechizos y rangos nuevos). Sin datos: costos que el juego ya te
-- enseno, del rango que aprendes (el 1 en un hechizo nuevo); si falta, lo dice sin inventar.
function WowF.lineaCostoEntrenar(nivel, nombres)
  if not WowF.entrenamientoActivo() or type(nombres) ~= "table" then return nil end
  local r = WowF.costosDelNivel(nivel)
  if r then
    if #r.lista == 0 then
      if #nombres == 0 then return nil end
      return marcar(GRIS .. L("Costo: aun no hay datos de WoW Forever para esto; pendiente de actualizar. Lo veras al abrir el entrenador.",
        "Cost: no WoW Forever data for this yet; pending update. You will see it when you open the trainer.") .. "|r")
    end
    local n = #r.lista
    local que = (n == 1) and L("1 hechizo", "1 spell") or L(n .. " hechizos y rangos", n .. " spells and ranks")
    local fuente = (r.vistos == n) and L("visto en tu entrenador", "seen at your trainer") or L("precio de WoW Forever", "WoW Forever price")
    local a = alcance(r.total)
    return marcar(ORO .. L("Entrenar lo de este nivel: ", "Training for this level: ") .. dinero(r.total) .. "|r" .. GRIS .. " (" .. que .. ", " .. fuente .. ")|r" .. (a and (" - " .. a) or ""))
  end
  if #nombres == 0 then return nil end
  local token = claseJugador()
  local guardados = token and type(db().costosEntrenador) == "table" and db().costosEntrenador[token]
  local total, conocidos = 0, 0
  local datos = token and type(WowFHechizos) == "table" and WowFHechizos[token]
  if type(guardados) == "table" then
    for _, nom in ipairs(nombres) do
      -- 15-oct: el rango que aprendes al llegar a este nivel es el 1 (antes tomaba el mas alto visto = mas caro)
      local c
      local d = type(datos) == "table" and datos[nom]
      if type(d) == "table" and type(d[2]) == "number" then c = numero(guardados[d[2]]) end
      if not c then c = numero(guardados[nom]) or numero(guardados[nom .. " Rank 1"]) or numero(guardados[nom .. " Rango 1"]) end
      if c then total = total + c; conocidos = conocidos + 1 end
    end
  end
  if conocidos == 0 then
    return marcar(GRIS .. L("Costo: lo veras al abrir el entrenador (te dira si te alcanza).",
      "Cost: you will see it when you open the trainer (it tells you if you can afford it).") .. "|r")
  end
  local parte = (conocidos < #nombres) and L(" (de " .. conocidos .. " de " .. #nombres .. " hechizos)", " (for " .. conocidos .. " of " .. #nombres .. " spells)") or ""
  local a = alcance(total)
  return marcar(ORO .. L("Costo visto en tu entrenador: ", "Cost seen at your trainer: ") .. dinero(total) .. "|r" .. parte .. (a and (" - " .. a) or ""))
end

-- ===================== Ventana junto al entrenador =====================
local marco
local abierto = false
-- 9-oct: la ventanita se quedaba fija (Andy): este cliente no siempre manda TRAINER_CLOSED ni usa ClassTrainerFrame.
-- Ahora se cierra con la X, al cerrarse la ventana del entrenador, con PLAYER_INTERACTION_MANAGER_FRAME_HIDE o, si no se
-- encuentra la ventana del entrenador, sola a los ESPERA segundos.
local ESPERA = 15
local function cerrar() abierto = false; if marco then marco:Hide() end end
WowF.cerrarEntrenamiento = cerrar
WowF.marcoEntrenamiento = function() return marco end -- para las pruebas
local function ventanaEntrenador()
  local f = _G.ClassTrainerFrame
  if f and f.IsShown and f:IsShown() then return f end
  return nil
end
local function vigilar(self, dt)
  self.t = (self.t or 0) + (dt or 0)
  if self.t < 0.5 then return end
  self.edad = (self.edad or 0) + self.t; self.t = 0
  local v = ventanaEntrenador()
  if v then
    if not self.visto then self.visto = true; self:ClearAllPoints(); self:SetPoint("TOPLEFT", v, "TOPRIGHT", 4, -20) end
  elseif self.visto or self.edad >= ESPERA then
    cerrar()
  end
end
local function crearMarco()
  if marco then return marco end
  marco = CreateFrame("Frame", "wowFEntrenamiento", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  marco:SetSize(250, 64)
  marco:SetFrameStrata("DIALOG")
  -- 11-oct (hibrido): fondo de piedra, cabecera pequena "Forever Guide", titulo serif y detalle en Signika
  local E = WowF.estilo
  E.marco(marco, "panel")
  marco.cab = E.cabecera(marco, 20)
  marco.cab.titulo:SetText("Forever Guide")
  marco.titulo = E.titulo(marco, nil, 13)
  marco.titulo:SetPoint("TOPLEFT", 12, -34)
  marco.titulo:SetWidth(226)
  marco.cuerpo = E.cuerpo(marco, nil, 11)
  marco.cuerpo:SetPoint("TOPLEFT", marco.titulo, "BOTTOMLEFT", 0, -6)
  marco.cuerpo:SetWidth(226)
  if marco.cuerpo.SetSpacing then marco.cuerpo:SetSpacing(2) end
  -- Retrato redondo del entrenador (wowF_Retratos.lua) a la izquierda; el texto se corre a la derecha
  if WowF.marcoRetrato then
    marco.retrato = WowF.marcoRetrato(marco, 30)
    marco.retrato:SetPoint("TOPLEFT", 10, -30)
    marco.titulo:ClearAllPoints()
    marco.titulo:SetPoint("TOPLEFT", 46, -34)
    marco.titulo:SetWidth(192)
    marco.cuerpo:SetWidth(192)
  end
  local x =CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
  E.boton(x, "cuero", 11)
  x:SetSize(18, 18); x:SetText("X")
  x:SetPoint("RIGHT", marco.cab.fondo, "RIGHT", -4, 0)
  x:SetScript("OnClick", cerrar)
  marco.cerrar = x
  marco:EnableMouse(true)
  marco:SetScript("OnMouseUp", function(_, boton) if boton == "RightButton" then cerrar() end end)
  marco:SetScript("OnUpdate", vigilar)
  marco:Hide()
  return marco
end

local ultimoTexto
-- Arma y muestra el resumen. Devuelve el texto (para las pruebas) o nil
function WowF.mostrarEntrenamiento()
  if not WowF.entrenamientoActivo() then if marco then marco:Hide() end return nil end
  local r = WowF.leerEntrenador()
  if not r then if marco then marco:Hide() end return nil end
  local titulo, cuerpo
  if r.n == 0 then
    titulo = L("Entrenador: nada nuevo por ahora", "Trainer: nothing new for now")
    cuerpo = GRIS .. L("Vuelve cuando subas de nivel.", "Come back when you level up.") .. "|r"
  else
    titulo = L("Entrenar todo: ", "Train everything: ") .. ORO .. dinero(r.total) .. "|r" .. GRIS .. " (" .. r.n .. ")|r"
    cuerpo = alcance(r.total) or (GRIS .. L("No se pudo leer tu dinero.", "Could not read your money.") .. "|r")
    if r.sinCosto > 0 then cuerpo = cuerpo .. "\n" .. GRIS .. L("Sin costo leido: " .. r.sinCosto, "Cost not readable: " .. r.sinCosto) .. "|r" end
  end
  local m = crearMarco()
  m.titulo:SetText(marcar(titulo)); m.cuerpo:SetText(marcar(cuerpo))
  local h1 = numero(llamar(m.titulo.GetStringHeight, m.titulo)) or 16
  local h2 = numero(llamar(m.cuerpo.GetStringHeight, m.cuerpo)) or 14
  m:SetHeight(math.max(70, math.floor(34 + h1 + 6 + h2 + 12)))
  m:ClearAllPoints()
  local padre = ventanaEntrenador()
  if padre then m:SetPoint("TOPLEFT", padre, "TOPRIGHT", 4, -20)
  else m:SetPoint("TOP", UIParent, "TOP", 0, -140) end
  m.t, m.edad, m.visto = 0, 0, padre and true or false
  if m.retrato then pcall(m.retrato.poner, m.retrato, { unidad = "npc", npc = WowF.npcDeUnidad and WowF.npcDeUnidad("npc"), icono = "Interface\\Icons\\INV_Misc_Book_09" }) end
  m:Show()
  ultimoTexto = titulo .. " | " .. cuerpo
  -- Una linea en el chat por visita (TRAINER_UPDATE no la repite)
  return ultimoTexto
end
WowF.entrenamientoUltimo = function() return ultimoTexto end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do pcall(ev.RegisterEvent, ev, e) end
local TIPO_ENTRENADOR = (type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" and Enum.PlayerInteractionType.Trainer) or 7
ev:SetScript("OnEvent", function(_, evento, tipo)
  if evento == "TRAINER_CLOSED" then cerrar() return end
  if evento == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then if tipo == TIPO_ENTRENADOR then cerrar() end return end
  if evento == "TRAINER_UPDATE" and not abierto then return end
  local primera = (evento == "TRAINER_SHOW")
  abierto = true
  local ok, t = pcall(WowF.mostrarEntrenamiento)
  if ok and t and primera then print(PREFIJO .. marcar(t:gsub(" | ", " - "))) end
end)

-- Casilla en Ajustes (wowF_Opciones.lua)
if WowF.registrarCasillaOpciones then WowF.registrarCasillaOpciones("entrenamiento", function() return L("Entrenador de clase: decirme si me alcanza el oro", "Class trainer: tell me if I can afford training") end) end

-- ===================== /wowf entrenamiento =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "entrenamiento" or orden == "training" then
    local t = db()
    if resto == "off" or resto == "no" then t.entrenamiento = false elseif resto == "on" or resto == "si" then t.entrenamiento = true
    else t.entrenamiento = not WowF.entrenamientoActivo() end
    if not WowF.entrenamientoActivo() and marco then marco:Hide() end
    local extra = ""
    if not WowF.entrenamientoDisponible() then extra = GRIS .. L(" (este cliente no deja leer el entrenador: no hara nada)", " (this client does not let addons read the trainer: it will do nothing)") .. "|r" end
    print(PREFIJO .. L("costo del entrenador ", "trainer cost ") .. (WowF.entrenamientoActivo() and (VERDE .. L("ENCENDIDO", "ON")) or (GRIS .. L("APAGADO", "OFF"))) .. "|r" ..
      extra .. L(". /wowf entrenamiento on|off", ". /wowf training on|off"))
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
