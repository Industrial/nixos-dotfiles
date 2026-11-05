-- Forever Leveling Guide: atajos de teclado (11-oct, calidad de vida del rediseno).
-- Bindings.xml (lo carga el juego solo) llama a WowF_Atajo("libro"|"panel"|"limpiar"|"ajustes"|"diario").
-- Se asignan en Opciones > Atajos de teclado > AddOns > Forever Leveling Guide. Sin tecla asignada por defecto.

WowF = WowF or {}
local function L(es, en) return (WowF.enIngles and WowF.enIngles()) and en or es end

-- Nombres en la ventana de atajos del juego (al entrar, ya con tu idioma elegido)
local function nombres()
  BINDING_HEADER_FOREVERLEVELINGGUIDE = "Forever Leveling Guide"
  BINDING_NAME_WOWF_LIBRO = L("Abrir o cerrar el plan completo", "Open or close the full plan")
  BINDING_NAME_WOWF_PANEL = L("Mostrar u ocultar el panel", "Show or hide the panel")
  BINDING_NAME_WOWF_LIMPIAR = L("Limpiar el mapa (rutas y marcas)", "Clear the map (routes and marks)")
  BINDING_NAME_WOWF_AJUSTES = L("Abrir los ajustes", "Open the settings")
  BINDING_NAME_WOWF_DIARIO = L("Abrir o cerrar el diario de mazmorras (la recomendada)", "Open or close the dungeon journal (recommended one)")
end
nombres()
WowF.atajosNombres = nombres

function WowF_Atajo(cual)
  if cual == "libro" then
    local libro = _G.wowFLibro
    if libro and libro.IsShown and libro:IsShown() then libro:Hide()
    elseif WowF.abrirLibro then WowF.abrirLibro() end
  elseif cual == "panel" then
    if SlashCmdList and SlashCmdList["WOWF"] then SlashCmdList["WOWF"]("panel") end
  elseif cual == "limpiar" then
    if WowF.limpiarRutas then WowF.limpiarRutas(false) end
  elseif cual == "ajustes" then
    if WowF.abrirOpciones then WowF.abrirOpciones() end
  elseif cual == "diario" then -- 11-oct (djextra): diario de mazmorras en la recomendada
    local libro = _G.wowFLibro or WowF.libro
    if libro and libro.IsShown and libro:IsShown() then libro:Hide()
    elseif WowF.abrirDiarioRecomendado then WowF.abrirDiarioRecomendado() end
  end
end

local alEntrar = CreateFrame("Frame")
pcall(alEntrar.RegisterEvent, alEntrar, "PLAYER_LOGIN")
alEntrar:SetScript("OnEvent", function() pcall(nombres) end)
