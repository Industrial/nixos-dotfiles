-- wowF Boton: boton redondo en el minimapa. Clic: plan completo · clic derecho: diario de la mazmorra recomendada · Mayus + clic derecho: panel.
-- Se arrastra alrededor del minimapa; la posicion se guarda en WowFExportarDB.minimapa.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
if not Minimap then return end

local b = CreateFrame("Button", "wowFBotonMinimapa", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local icono = b:CreateTexture(nil, "BACKGROUND")
icono:SetSize(20, 20)
icono:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
icono:SetPoint("TOPLEFT", 7, -5)
local borde = b:CreateTexture(nil, "OVERLAY")
borde:SetSize(53, 53)
borde:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
borde:SetPoint("TOPLEFT")

-- 5-oct (Andy): en el borde, como los demas botones, sin tapar el minimapa. El radio sale del tamano real
-- del minimapa (el de este cliente es mas grande que el clasico de 140, donde 80 ya quedaba en el borde).
local function radio()
  local w = Minimap.GetWidth and Minimap:GetWidth()
  if type(w) ~= "number" or w < 100 or w > 400 then w = 140 end
  return w / 2 + 10
end
local function colocar()
  local a = math.rad(WowFExportarDB.minimapa or 200)
  local r = radio()
  local x, y = math.cos(a), math.sin(a)
  -- minimapa cuadrado (algunos addons lo cambian): pegado al borde del cuadrado
  local forma = GetMinimapShape and GetMinimapShape()
  if forma == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
  end
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
  if WowF.aplicarMinimapa then WowF.aplicarMinimapa() end
end
-- 11-oct (ideas de GearQuest): ocultar el boton (WowFExportarDB.ocultarMinimapa = true). Casilla en Ajustes y
-- /wowf minimapa|minimap on|off (wowF_Caza.lua). Oculto = /wowf sigue abriendo el plan.
function WowF.aplicarMinimapa()
  if type(WowFExportarDB) == "table" and WowFExportarDB.ocultarMinimapa == true then b:Hide() else b:Show() end
end
colocar()
b:RegisterEvent("PLAYER_ENTERING_WORLD")
b:SetScript("OnEvent", colocar)
if Minimap.HookScript then Minimap:HookScript("OnSizeChanged", colocar) end

local function arrastrar()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  if not (mx and px and s) then return end
  local atan2 = math.atan2 or math.atan
  WowFExportarDB.minimapa = math.deg(atan2(py / s - my, px / s - mx))
  colocar()
end
b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", arrastrar) end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- 11-oct (djextra): clic derecho = diario de mazmorras en la recomendada (WowF.mazmorrasParaTi); Mayus + clic derecho = el panel
local function L(es, en) return (WowF.enIngles and WowF.enIngles()) and en or es end
local function clic(_, boton)
  if boton == "RightButton" then
    if IsShiftKeyDown and IsShiftKeyDown() then
      if SlashCmdList and SlashCmdList.WOWF then SlashCmdList.WOWF("panel") end
    elseif WowF.abrirDiarioRecomendado then WowF.abrirDiarioRecomendado()
    elseif SlashCmdList and SlashCmdList.WOWF then SlashCmdList.WOWF("panel") end
  elseif WowF.abrirLibro then
    if WowF.libro and WowF.libro:IsShown() then WowF.libro:Hide() else WowF.abrirLibro() end
  end
end
b:SetScript("OnClick", clic)
WowF._botonClic = clic -- para las pruebas
b:SetScript("OnEnter", function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("|cffffd100Forever Leveling Guide|r\n|cff33ff66" .. L("Clic:", "Click:") .. "|r " .. L("tu plan completo", "your full plan")
    .. "\n|cff33ff66" .. L("Clic derecho:", "Right-click:") .. "|r " .. L("diario de la mazmorra recomendada", "journal of the recommended dungeon")
    .. "\n|cff33ff66" .. L("Mayús + clic derecho:", "Shift + right-click:") .. "|r " .. L("mostrar u ocultar el panel", "show or hide the panel")
    .. "\n|cff999999" .. L("Arrastra para moverlo", "Drag to move it") .. "|r", 1, 1, 1, 1, true)
  GameTooltip:Show()
end)
b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
WowF.botonMinimapa = b
