-- Forever Leveling Guide: el probador del juego (Dressing Room, la ventana de "Ver como queda") se puede mover a cualquier sitio
-- (12-oct, Andy: "que se pueda mover tambien por donde yo quiera... porque basicamente no lo puedes hacer").
-- Se arrastra desde el borde o el titulo (el modelo sigue girando con el raton) y tambien desde la lista de piezas de al lado.
-- La posicion se guarda en WowFExportarDB.probadorPos y se vuelve a poner cada vez que se abre (el juego la recoloca al mostrarla).
-- Nada en combate: mover marcos del juego en combate puede dar el aviso de "blocked".
WowF = WowF or {}

local hecho = false

local function enCombate()
  return InCombatLockdown and InCombatLockdown() and true or false
end

local function guardar(f)
  if not WowFExportarDB then return end
  local ok, a, _, b, x, y = pcall(f.GetPoint, f, 1)
  if ok and a and type(x) == "number" and type(y) == "number" then
    WowFExportarDB.probadorPos = { a, b or a, x, y }
  end
end

local function reponer(f)
  local g = WowFExportarDB and WowFExportarDB.probadorPos
  if type(g) ~= "table" or type(g[3]) ~= "number" or type(g[4]) ~= "number" or enCombate() then return end
  pcall(function()
    f:ClearAllPoints()
    f:SetPoint(g[1], UIParent, g[2], g[3], g[4])
  end)
end

local function hacerArrastrable(asa, f)
  if not asa or not asa.HookScript then return end
  pcall(function()
    asa:EnableMouse(true)
    asa:RegisterForDrag("LeftButton")
    asa:HookScript("OnDragStart", function()
      if enCombate() then return end
      pcall(f.StartMoving, f)
    end)
    asa:HookScript("OnDragStop", function()
      pcall(f.StopMovingOrSizing, f)
      guardar(f)
    end)
  end)
end

local function preparar()
  local f = DressUpFrame
  if hecho or not f or enCombate() or WowF.interfazMando() then return end -- 22-oct: con mando no se toca la ventana del juego (FLG-ERR SetPreferredGamepadInteractTarget)
  hecho = true
  pcall(function()
    f:SetMovable(true)
    f:SetClampedToScreen(true)
  end)
  hacerArrastrable(f, f)
  -- la lista de piezas de al lado (segun la version del cliente) y la barra de titulo, si existen
  for _, nombre in ipairs({ "OutfitDetailsPanel", "TitleContainer", "TitleBar" }) do
    local asa = rawget(f, nombre)
    if type(asa) == "table" then hacerArrastrable(asa, f) end
  end
  f:HookScript("OnShow", function(self)
    reponer(self)
    -- el juego coloca la ventana un instante despues de mostrarla: se repone otra vez
    if C_Timer and C_Timer.After then C_Timer.After(0, function() if self:IsShown() then reponer(self) end end) end
  end)
  if f:IsShown() then reponer(f) end
end
WowF.prepararProbador = preparar

-- el probador puede cargarse tarde (Blizzard_UIPanels / al primer uso): se prueba al entrar y cada vez que se carga un addon
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  if not hecho then preparar() end
end)

-- si alguien abre el probador antes de que este listo (p. ej. desde el Diario), se prepara en ese momento
if hooksecurefunc then
  pcall(hooksecurefunc, "DressUpItemLink", function() if not hecho then preparar() end end)
end
