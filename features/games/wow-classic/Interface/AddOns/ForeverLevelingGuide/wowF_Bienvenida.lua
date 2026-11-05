-- wowF Bienvenida: pantalla de inicio la primera vez que se instala el addon (elegir idioma + recorrido por cada parte del addon).
-- Sale una sola vez por cuenta (WowFExportarDB.bienvenida); se vuelve a abrir con /wowf ayuda.
-- Textos en los dos idiomas con L(es, en): no pasan por el diccionario.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end

-- Cada paso: titulo, icono y texto. Se arman al mostrar (el idioma puede cambiar).
-- 13-oct (Andy: "que el onboarding explique el addon de punta a punta"): un paso por cada parte (panel, boton del minimapa, plan completo,
-- mazmorras, mapa y rutas, avisos, ventanas y ajustes) con donde esta, para que sirve y como se usa. Se puede saltar en cualquier paso;
-- el detalle completo queda en la Guia del addon (wowF_Guia.lua, /wowf guia).
local function pasos()
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  local t = {
    { L("Idioma", "Language"), "Interface\\Icons\\INV_Misc_Note_02",
      L("La guía está en español.\n\n"
        .. GRIS .. "Los nombres del juego (hechizos, objetos, zonas) salen como en tu cliente.\n\n"
        .. "Puedes cambiarlo cuando quieras: /wowf idioma|r",
        "The guide is in English.\n\n"
        .. GRIS .. "Game names (spells, items, zones) stay as in your client.\n\n"
        .. "You can change it any time: /wowf language|r"), idioma = true },
    { L("¡Hola! Esto es Forever Guide", "Hi! This is Forever Guide"), "Interface\\Icons\\INV_Misc_Book_09",
      L("Te dice qué hacer para subir de nivel, paso a paso, dentro del juego.\n\n"
        .. "Arma un plan para TU personaje (clase, rama, nivel, profesiones, equipo y facción) y lo cambia solo mientras juegas.\n\n"
        .. VERDE .. "No tienes que configurar nada.|r\n\n"
        .. GRIS .. "Estos pasos te enseñan dónde está cada cosa. Si ya lo conoces, pulsa " .. BLANCO .. "Saltar|r" .. GRIS .. ": todo queda explicado en la " .. BLANCO .. "Guía del addon|r" .. GRIS .. " (botón ? del plan o /wowf guia).|r",
        "It tells you what to do to level up, step by step, inside the game.\n\n"
        .. "It builds a plan for YOUR character (class, spec, level, professions, gear and faction) and updates it by itself as you play.\n\n"
        .. VERDE .. "You don't need to set anything up.|r\n\n"
        .. GRIS .. "These steps show you where everything is. If you already know it, press " .. BLANCO .. "Skip|r" .. GRIS .. ": everything is explained in the " .. BLANCO .. "Addon guide|r" .. GRIS .. " (? button in the plan or /wowf guide).|r") },
    { L("Importante: versión beta", "Important: beta version"), "Interface\\Icons\\INV_Misc_QuestionMark",
      L("Esta guía está basada en los datos de la beta de WoW Forever, que hoy llega hasta el " .. ORO .. "nivel " .. tope .. "|r.\n\n"
        .. "Está en pleno desarrollo y se actualiza con cada build nueva. Algunas cosas pueden fallar o cambiar: " .. VERDE .. "te pedimos disculpas de antemano|r.\n\n"
        .. NARANJA .. "Hay datos que aún no están confirmados. La guía lo dice con un aviso en naranja y nunca inventa nada: se irán completando en próximas actualizaciones.|r",
        "This guide is based on WoW Forever beta data, which currently goes up to " .. ORO .. "level " .. tope .. "|r.\n\n"
        .. "It is under active development and is updated with every new build. Some things may break or change: " .. VERDE .. "we apologize in advance|r.\n\n"
        .. NARANJA .. "Some data is not confirmed yet. The guide says so with an orange notice and never makes anything up: it will be filled in future updates.|r") },
    { L("El panel", "The panel"), "Interface\\Icons\\INV_Misc_Map_01",
      L(ORO .. "Dónde:|r a la derecha de tu pantalla.\n\n"
        .. ORO .. "Para qué:|r te dice lo PRÓXIMO: a qué zona ir, qué mazmorra te toca, qué aprender, qué pieza buscar. Haz " .. VERDE .. "clic|r en una línea y te pone la ruta en el mapa.\n\n"
        .. ORO .. "Cómo se maneja:|r\n"
        .. "• Arrástralo para moverlo.\n"
        .. "• " .. VERDE .. "–|r lo pliega; el " .. VERDE .. "engranaje|r abre Ajustes.\n"
        .. "• " .. VERDE .. "Plan completo|r abre todo lo demás.",
        ORO .. "Where:|r on the right side of your screen.\n\n"
        .. ORO .. "What for:|r it shows what's NEXT: which zone to go to, which dungeon is yours, what to learn, which item to look for. " .. VERDE .. "Click|r a line and it sets the route on the map.\n\n"
        .. ORO .. "How to handle it:|r\n"
        .. "• Drag it to move it.\n"
        .. "• " .. VERDE .. "–|r folds it; the " .. VERDE .. "gear|r opens Settings.\n"
        .. "• " .. VERDE .. "Full plan|r opens everything else.") },
    { L("Botón del minimapa", "Minimap button"), "Interface\\Icons\\INV_Misc_Book_09",
      L("El botón redondo con el libro, en el borde del minimapa:\n\n"
        .. VERDE .. "Clic|r: abre o cierra tu plan completo.\n"
        .. VERDE .. "Clic derecho|r: el diario de la mazmorra que te toca.\n"
        .. VERDE .. "Mayús + clic derecho|r: muestra u oculta el panel.\n"
        .. VERDE .. "Arrastrar|r: lo mueves alrededor del minimapa.\n\n"
        .. GRIS .. "¿Te estorba? Se oculta en Ajustes. /wowf siempre abre el plan.|r",
        "The round button with the book, on the edge of the minimap:\n\n"
        .. VERDE .. "Click|r: opens or closes your full plan.\n"
        .. VERDE .. "Right-click|r: the journal of the dungeon that is right for you.\n"
        .. VERDE .. "Shift + right-click|r: shows or hides the panel.\n"
        .. VERDE .. "Drag|r: moves it around the minimap.\n\n"
        .. GRIS .. "In your way? Hide it in Settings. /wowf always opens the plan.|r") },
    { L("Tu plan completo", "Your full plan"), "Interface\\Icons\\INV_Misc_Note_01",
      L("Pestañas de arriba:\n\n"
        .. ORO .. "Progreso|r  qué te toca en cada nivel y dónde subir\n"
        .. ORO .. "Talentos|r  dónde va cada punto, en orden\n"
        .. ORO .. "Combate|r  rotación (PvE y PvP) y macros de un clic\n"
        .. ORO .. "Profesiones|r  cuáles coger y cómo subirlas\n"
        .. ORO .. "Equipo|r  las piezas que te tocan y de dónde salen\n"
        .. ORO .. "Mazmorras|r  el diario de cada mazmorra\n"
        .. ORO .. "BiS " .. tope .. "|r  lo mejor para tu rama, mascota y consumibles\n\n"
        .. "A la izquierda: " .. VERDE .. "idioma|r, " .. VERDE .. "Ajustes|r, " .. VERDE .. "Novedades|r y " .. VERDE .. "?|r (la Guía del addon).",
        "Tabs at the top:\n\n"
        .. ORO .. "Progress|r  what to do at each level and where to level\n"
        .. ORO .. "Talents|r  where each point goes, in order\n"
        .. ORO .. "Combat|r  rotation (PvE and PvP) and one-click macros\n"
        .. ORO .. "Professions|r  which ones to pick and how to level them\n"
        .. ORO .. "Gear|r  the items for you and where they come from\n"
        .. ORO .. "Dungeons|r  the journal of each dungeon\n"
        .. ORO .. "BiS " .. tope .. "|r  the best for your spec, pet and consumables\n\n"
        .. "On the left: " .. VERDE .. "language|r, " .. VERDE .. "Settings|r, " .. VERDE .. "What's new|r and " .. VERDE .. "?|r (the Addon guide).") },
    { L("Mazmorras", "Dungeons"), "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      L("En la pestaña " .. ORO .. "Mazmorras|r cada una tiene su ficha:\n\n"
        .. ORO .. "Resumen|r  nivel y cómo llegar\n"
        .. ORO .. "Jefes y botín|r  lo que te sirve de cada jefe\n"
        .. ORO .. "Misiones|r  quién las da y a quién se entregan\n"
        .. ORO .. "Ruta|r  lo que te falta para ir\n"
        .. ORO .. "Mapa|r  los jefes en orden y lo básico de cada pelea\n\n"
        .. GRIS .. "Dentro, el jefe que suelta tu pieza sale marcado. " .. BLANCO .. "Ctrl + clic|r" .. GRIS .. " en una pieza = probártela.|r",
        "In the " .. ORO .. "Dungeons|r tab, each one has its own page:\n\n"
        .. ORO .. "Overview|r  level and how to get there\n"
        .. ORO .. "Bosses and loot|r  what's useful for you from each boss\n"
        .. ORO .. "Quests|r  who gives them and where to turn them in\n"
        .. ORO .. "Path|r  what you still need to go\n"
        .. ORO .. "Map|r  bosses in order and the basics of each fight\n\n"
        .. GRIS .. "Inside, the boss that drops your item is marked. " .. BLANCO .. "Ctrl + click|r" .. GRIS .. " on an item = try it on.|r") },
    { L("Mapa y rutas", "Map and routes"), "Interface\\Icons\\INV_Misc_Map02",
      L("Al hacer clic en una mazmorra, misión o pieza, sale un recuadro con " .. ORO .. "PASO 1 DE N|r y un alfiler azul. Avanza solo al llegar. Se mueve arrastrándolo; la X lo quita (o /wowf parar).\n\n"
        .. "En el mapa verás tu ruta numerada, el |cffcc66ff!|r morado de las misiones de mazmorra y los iconos de los entrenadores.\n\n"
        .. ORO .. "Iconos de entrenadores:|r botón abajo a la izquierda del mapa (mías / todas / ninguna). Su " .. VERDE .. "tamaño|r y su " .. VERDE .. "opacidad|r, en Ajustes.",
        "When you click a dungeon, quest or item, a box shows up with " .. ORO .. "STEP 1 OF N|r and a blue pin. It moves on when you arrive. Drag it to move it; the X removes it (or /wowf stop).\n\n"
        .. "On the map you'll see your numbered route, the purple |cffcc66ff!|r of dungeon quests and the trainer icons.\n\n"
        .. ORO .. "Trainer icons:|r button at the bottom left of the map (mine / all / none). Their " .. VERDE .. "size|r and " .. VERDE .. "opacity|r are in Settings.") },
    { L("Avisos", "Alerts"), "Interface\\Icons\\INV_Misc_Bag_10",
      L("La guía te avisa sola:\n\n"
        .. "• " .. ORO .. "Al subir de nivel|r: hechizos nuevos, qué fabricar, mazmorras nuevas.\n"
        .. "• " .. ORO .. "Botín|r: " .. VERDE .. "verde|r te sirve, " .. ORO .. "dorado|r vale oro, " .. CELESTE .. "azul|r guárdalo para tu rama final.\n"
        .. "• " .. ORO .. "Bolsas llenas|r (al entrar, con 2 huecos o menos) y " .. ORO .. "equipo roto|r (menos del 20 %).\n"
        .. "• Recompensa de misión, mejoras en el tooltip, entrenador y vendedor.\n\n"
        .. GRIS .. "Cada aviso se apaga en Ajustes. Si no quieres ventanas al subir de nivel, apaga \"Ventanas al subir de nivel\": el resumen sale en el chat.|r",
        "The guide warns you by itself:\n\n"
        .. "• " .. ORO .. "On level up|r: new spells, what to craft, new dungeons.\n"
        .. "• " .. ORO .. "Loot|r: " .. VERDE .. "green|r is useful, " .. ORO .. "gold|r is worth gold, " .. CELESTE .. "blue|r save it for your final spec.\n"
        .. "• " .. ORO .. "Full bags|r (at login, with 2 free slots or fewer) and " .. ORO .. "broken gear|r (below 20 %).\n"
        .. "• Quest rewards, upgrades in the tooltip, trainer and vendor.\n\n"
        .. GRIS .. "Each alert can be turned off in Settings. If you don't want pop-ups on level up, turn off \"Level-up popups\": the summary goes to chat.|r") },
    { L("Ventanas y ajustes", "Windows and settings"), "Interface\\Icons\\INV_Misc_Gear_01",
      L(ORO .. "Mover:|r arrastra cualquier ventana (el plan, por el estandarte o el borde).\n"
        .. ORO .. "Cerrar:|r con la " .. VERDE .. "X|r o la tecla " .. VERDE .. "Esc|r. El panel no se cierra: se pliega con " .. VERDE .. "–|r.\n\n"
        .. ORO .. "Ajustes|r (botón del plan, engranaje del panel o /wowf ajustes):\n"
        .. "• Tamaño de las ventanas, letra y opacidad del fondo.\n"
        .. "• Tamaño y opacidad de los iconos del mapa.\n"
        .. "• Cada aviso, por separado.\n"
        .. "• Ocultar el botón del minimapa.\n\n"
        .. GRIS .. "Restablecer lo deja todo como venía.|r",
        ORO .. "Move:|r drag any window (the plan, by the banner or the border).\n"
        .. ORO .. "Close:|r with the " .. VERDE .. "X|r or the " .. VERDE .. "Esc|r key. The panel doesn't close: fold it with " .. VERDE .. "–|r.\n\n"
        .. ORO .. "Settings|r (button in the plan, gear on the panel or /wowf settings):\n"
        .. "• Window size, text size and background opacity.\n"
        .. "• Size and opacity of the map icons.\n"
        .. "• Each alert, one by one.\n"
        .. "• Hide the minimap button.\n\n"
        .. GRIS .. "Reset puts everything back to default.|r") },
    { L("Los colores", "The colors"), "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
      L(VERDE .. "Verde|r = ya puedes hacerlo, o haz clic ahí.\n"
        .. ORO .. "Dorado|r = lo tendrás más adelante.\n"
        .. NARANJA .. "Naranja|r = te falta algo, o aún no hay datos.\n"
        .. GRIS .. "Gris|r = solo información.\n\n"
        .. BLANCO .. "¿Dudas?|r La " .. ORO .. "Guía del addon|r lo explica todo: botón " .. VERDE .. "?|r del plan o " .. ORO .. "/wowf guia|r.\n\n"
        .. BLANCO .. "Comandos:|r " .. ORO .. "/wowf|r abre tu plan · " .. ORO .. "/wowf ayuda|r vuelve a esta pantalla · " .. ORO .. "/wowf idioma|r cambia el idioma · " .. ORO .. "/wowf novedades|r lo nuevo de esta versión.",
        VERDE .. "Green|r = you can do it now, or click it.\n"
        .. ORO .. "Gold|r = you will get it later.\n"
        .. NARANJA .. "Orange|r = something is missing, or no data yet.\n"
        .. GRIS .. "Gray|r = information only.\n\n"
        .. BLANCO .. "Questions?|r The " .. ORO .. "Addon guide|r explains everything: " .. VERDE .. "?|r button in the plan or " .. ORO .. "/wowf guide|r.\n\n"
        .. BLANCO .. "Commands:|r " .. ORO .. "/wowf|r opens your plan · " .. ORO .. "/wowf help|r shows this screen again · " .. ORO .. "/wowf language|r changes the language · " .. ORO .. "/wowf changes|r what's new in this version.") },
  }
  if WowF.pasoAyudaLegacy then table.insert(t, #t, WowF.pasoAyudaLegacy()) end -- 8-oct: Legacy + SkillUp Forever (wowF_Legacy.lua)
  return t
end

-- ===================== Ventana =====================
local v = CreateFrame("Frame", "wowFBienvenida", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
v:SetSize(440, 340)
v:SetPoint("CENTER", 0, 60)
v:SetFrameStrata("DIALOG")
v:SetMovable(true)
v:EnableMouse(true)
v:RegisterForDrag("LeftButton")
v:SetScript("OnDragStart", v.StartMoving)
v:SetScript("OnDragStop", v.StopMovingOrSizing)
v:SetClampedToScreen(true)
if v.SetBackdrop then
  v:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  v:SetBackdropColor(0.03, 0.03, 0.05, 0.96)
  v:SetBackdropBorderColor(1, 0.82, 0, 0.9)
end
WowF.estilo.marco(v, "tapa")
v:Hide()
WowF.cerrarConEsc("wowFBienvenida") -- Esc la cierra

-- 11-oct, rediseño "hibrido": tapa con icono en casilla, etiqueta brasa del paso, titulo serif, divisor, texto Signika y barra por tramos
local E = WowF.estilo
local ANCHO = 440
local casillaIc = E.textura and E.textura(v, "ARTWORK", 1, E.color.borde, 1) or v:CreateTexture(nil, "ARTWORK", nil, 1)
casillaIc:SetSize(46, 46)
casillaIc:SetPoint("TOPLEFT", 22, -24)
local icono = v:CreateTexture(nil, "ARTWORK", nil, 3)
icono:SetSize(42, 42)
icono:SetPoint("CENTER", casillaIc, "CENTER")
if icono.SetTexCoord then icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
local etiqueta = E.etiqueta(v, nil, nil, 9)
etiqueta:SetPoint("TOPLEFT", casillaIc, "TOPRIGHT", 14, -4)
etiqueta:SetPoint("RIGHT", v, "RIGHT", -44, 0)
local titulo = E.titulo(v, nil, 18)
titulo:SetPoint("TOPLEFT", etiqueta, "BOTTOMLEFT", 0, -5)
titulo:SetPoint("RIGHT", v, "RIGHT", -44, 0)
titulo:SetJustifyH("LEFT")
local cerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
E.boton(cerrar, "cuero")
cerrar:SetSize(18, 18)
cerrar:SetText("X")
cerrar:SetPoint("TOPRIGHT", -16, -18)
local divisor = E.divisor(v, nil, -82, 22, 22)
local texto = E.cuerpo(v, nil, 12)
texto:SetPoint("TOPLEFT", 24, -96)
texto:SetPoint("TOPRIGHT", -24, -96)
texto:SetJustifyH("LEFT")
texto:SetJustifyV("TOP")
if texto.SetSpacing then texto:SetSpacing(3) end
local tramos = E.tramos(v, ANCHO - 48)
tramos:SetPoint("BOTTOMLEFT", 24, 48)
local cuenta = E.sub(v, nil, 9)
cuenta:SetPoint("BOTTOMRIGHT", -24, 58)

local atras = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
WowF.estilo.boton(atras, "cuero")
atras:SetSize(100, 24)
atras:SetPoint("BOTTOMLEFT", 16, 14)
local siguiente = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
WowF.estilo.boton(siguiente, "brasa")
siguiente:SetSize(130, 24)
siguiente:SetPoint("BOTTOMRIGHT", -16, 14)
-- 13-oct: Saltar (pasos 2 a N-1) o "Abrir la guia" (ultimo paso)
local saltar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
WowF.estilo.boton(saltar, "secundario")
saltar:SetSize(120, 24)
saltar:SetPoint("BOTTOM", 0, 14)
saltar:Hide()

-- Botones del paso de idioma
local function botonIdioma(etiqueta, x)
  local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  WowF.estilo.boton(b, "cuero")
  b:SetSize(150, 34)
  b:SetPoint("BOTTOM", x, 66)
  b:SetText(etiqueta)
  b:Hide()
  return b
end
local botonES = botonIdioma("Español", -82)
local botonEN = botonIdioma("English", 82)

local paso = 1
local function mostrar()
  local P = pasos()
  if paso < 1 then paso = 1 elseif paso > #P then paso = #P end
  local p = P[paso]
  etiqueta:SetText(E.mayus(L("Paso " .. paso .. " de " .. #P, "Step " .. paso .. " of " .. #P)))
  titulo:SetText(p[1])
  icono:SetTexture(p[2])
  -- El texto de los pasos lleva los colores del estilo viejo: el dorado de las palabras clave pasa al oro del estilo y el gris al tenue
  local cuerpo = tostring(p[3] or ""):gsub(ORO, E.cod.oro):gsub(GRIS, E.cod.tenue):gsub(BLANCO, E.cod.texto)
  texto:SetText(cuerpo)
  tramos:poner(paso, #P)
  cuenta:SetText(paso .. " / " .. #P)
  atras:SetText(L("Atras", "Back"))
  if paso == 1 then atras:Hide() else atras:Show() end
  -- En el paso de idioma solo se sigue eligiendo uno (el elegido sale en brasa, el otro en cuero)
  if p.idioma then
    local db = WowFExportarDB or {}
    botonES:SetText("Español")
    botonEN:SetText("English")
    E.boton(botonES, db.idioma == "es" and "brasa" or "cuero")
    E.boton(botonEN, db.idioma ~= "es" and "brasa" or "cuero")
    botonES:Show(); botonEN:Show(); siguiente:Hide()
  else
    botonES:Hide(); botonEN:Hide(); siguiente:Show()
  end
  siguiente:SetText(paso == #P and L("Abrir mi plan", "Open my plan") or L("Siguiente", "Next"))
  if p.idioma then saltar:Hide()
  else
    saltar:SetText(paso == #P and L("Abrir la guía", "Open the guide") or L("Saltar", "Skip"))
    saltar:Show()
  end
  -- Alto segun el texto: cabecera (96) + texto + sitio para los botones de idioma o la barra y los botones de abajo
  local alto = tonumber(texto.GetStringHeight and texto:GetStringHeight()) or 0
  if alto <= 0 then alto = 160 end
  v:SetHeight(math.max(300, math.floor(96 + alto + (p.idioma and 130 or 80))))
  v.pasoActual, v.totalPasos = paso, #P
end

-- Al cerrarla (por cualquier via) queda marcada como vista: no vuelve a salir sola
local function terminar()
  WowFExportarDB.bienvenida = 1
  v:Hide()
end
cerrar:SetScript("OnClick", terminar)
-- 4-nov (Andy: "al abrir el juego no me dio ninguna bienvenida"): si la oculta el juego (UIParent oculto: cinematica de
-- entrada, pantalla sin interfaz) NO cuenta como vista; vuelve a salir cuando se ve la interfaz
v:SetScript("OnHide", function()
  if UIParent and UIParent.IsShown and not UIParent:IsShown() then return end
  WowFExportarDB.bienvenida = 1; WowFExportarDB.idiomaVisto = 1
end)
atras:SetScript("OnClick", function() paso = paso - 1; mostrar() end)
-- Saltar: se cierra y queda marcada como vista; una linea en el chat dice donde esta todo explicado
saltar:SetScript("OnClick", function()
  local ultimo = paso >= #pasos()
  terminar()
  if ultimo then
    if WowF.abrirGuia then WowF.abrirGuia("inicio") end
  else
    print("|cff33ccffForever Guide|r: " .. L("Todo queda explicado en la Guía del addon: botón ? del plan completo o /wowf guia. /wowf ayuda repite estos pasos.",
      "Everything is explained in the Addon guide: ? button in the full plan or /wowf guide. /wowf help repeats these steps."))
  end
end)
siguiente:SetScript("OnClick", function()
  if paso >= #pasos() then
    terminar()
    if WowF.abrirLibro then WowF.abrirLibro("Progreso") end
  else paso = paso + 1; mostrar() end
end)

-- Elegir idioma: se guarda, se redibuja lo que esta abierto y se pasa al siguiente paso
local function elegirIdioma(cod)
  WowFExportarDB.idioma = cod
  if WowF.reidiomar then WowF.reidiomar() elseif WowF.panelActualizar then WowF.panelActualizar() end
  paso = paso + 1
  mostrar()
end
botonES:SetScript("OnClick", function() elegirIdioma("es") end)
botonEN:SetScript("OnClick", function() elegirIdioma("en") end)
WowF.bienvenidaIdioma = elegirIdioma

function WowF.abrirBienvenida(n)
  paso = n or 1
  mostrar()
  v:Show()
end
-- Para las pruebas: texto del paso que se ve y pasar al siguiente como si se hiciera clic
function WowF.bienvenidaTexto() return (titulo:GetText() or "") .. "\n" .. (texto:GetText() or "") .. "\n" .. (siguiente:GetText() or "") end
function WowF.bienvenidaSiguiente() local fn = siguiente:GetScript("OnClick"); if fn then fn(siguiente) end end
function WowF.bienvenidaSaltar() local fn = saltar:GetScript("OnClick"); if fn then fn(saltar) end end
function WowF.bienvenidaBotonSaltar() return saltar:IsShown() and (saltar:GetText() or "") or nil end
WowF.bienvenida = v
-- Si cambia el idioma con la bienvenida abierta (/wowf idioma), se redibuja el paso
function WowF.bienvenidaRedibujar() if v:IsShown() then mostrar() end end

-- ===================== Proteccion: la beta perdio las variables guardadas (5-oct) =====================
-- Si WowFExportarDB llega vacia (como recien instalado) pero el personaje ya tiene nivel > 5 o profesiones, no es alguien nuevo:
-- se perdieron sus ajustes. No se le repite la bienvenida: se rehace lo basico con lo que el personaje tiene AHORA (cualquier
-- raza, clase y faccion): la rama sale de sus talentos (Armar, sin rama guardada), las profesiones de las reales, el nivel y la
-- faccion del juego; el objetivo de profesiones solo si sus dos profesiones son exactamente las de UN objetivo de su clase; el
-- idioma, espanol si el cliente esta en espanol. Un aviso de una linea. Quien entra de verdad la primera vez (nivel 1-5, sin
-- profesiones) ve la bienvenida de siempre.
local estabaVacia = nil -- se decide en ADDON_LOADED, antes de que nadie escriba en la DB al entrar al mundo
local function dbVacia(db)
  if type(db) ~= "table" then return true end
  -- Solo campos que se escriben al jugar (nunca al cargar los archivos): bienvenida, idioma visto, personajes guardados
  for _, k in ipairs({ "bienvenida", "idiomaVisto", "personajes", "version", "ultimo", "objetivo", "rama", "avisos" }) do
    if db[k] ~= nil then return false end
  end
  return true
end
local function legible(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function nivelReal()
  local ok, n = pcall(UnitLevel, "player")
  return ok and tonumber(legible(n)) or 0
end
local function clavePj()
  local nombre = UnitName and UnitName("player") or "?"
  local reino = (GetRealmName and GetRealmName()) or ""
  return reino ~= "" and (nombre .. "-" .. reino) or nombre
end
-- Objetivo de profesiones a partir de las dos principales reales: solo si coinciden con las de un unico objetivo de la clase
local function objetivoPorProfesiones()
  if not WowF.profesionesPrincipales or not WowF.ORDEN_OBJETIVOS or type(WowFDatos) ~= "table" or not WowFDatos.clases then return nil end
  local okP, mias = pcall(WowF.profesionesPrincipales)
  if not okP or type(mias) ~= "table" or #mias < 2 then return nil end
  local _, token = UnitClass("player")
  local c = token and WowFDatos.clases[token]
  if not c or not c.recomendadas then return nil end
  local tengo = {}
  for _, id in ipairs(mias) do tengo[id] = true end
  local encontrado = nil
  for _, o in ipairs(WowF.ORDEN_OBJETIVOS) do
    local r = c.recomendadas[o]
    if r and #r == 2 and tengo[r[1]] and tengo[r[2]] then
      if encontrado then return nil end -- dos objetivos con las mismas profesiones: no se adivina
      encontrado = o
    end
  end
  return encontrado
end
-- Rehace lo de ESTE personaje (tambien sirve para los demas personajes de la cuenta cuando entren despues)
local function rehacerPersonaje()
  local db = WowFExportarDB
  db.rehechoPj = db.rehechoPj or {}
  local k = clavePj()
  if db.rehechoPj[k] then return end
  db.rehechoPj[k] = true
  -- Rama: sin elegida, el plan la toma de tus talentos (o la recomendada si aun no tienes puntos)
  if not (db.objetivo and db.objetivo[k]) then
    local o = objetivoPorProfesiones()
    if o and WowF.elegirObjetivo then WowF.elegirObjetivo(o) end
  end
end
function WowF.rehacerAjustes()
  local db = WowFExportarDB
  db.bienvenida, db.idiomaVisto = 1, 1
  db.rehecho = (date and date("%Y-%m-%d")) or "si"
  if db.idioma == nil then
    local ok, loc = pcall(GetLocale)
    if ok and type(loc) == "string" and loc:sub(1, 2) == "es" then db.idioma = "es" end
    if WowF.reidiomar then pcall(WowF.reidiomar) end
  end
  rehacerPersonaje()
  print("|cff33ccffForever Guide|r: " .. L("Se perdieron tus ajustes: los rehice con tu personaje (nivel " .. nivelReal() .. ", tus talentos y tus profesiones). Si es tu primera vez: /wowf ayuda",
    "Your settings were lost: I rebuilt them from your character (level " .. nivelReal() .. ", your talents and professions). First time here? /wowf help"))
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
end
-- Para las pruebas: lo que se decidio al cargar
function WowF.dbEstabaVacia() return estabaVacia end
-- 4-nov: personaje que ya jugaba (nivel > 5 o con profesiones). Con la DB vacia = instalacion nueva de alguien que ya usaba
-- el addon (p. ej. carpeta _forever_ nueva al lanzamiento): no ve la bienvenida, pero SI las novedades (wowF_Notas.lua)
function WowF.pjVeterano()
  if nivelReal() > 5 then return true end
  local okP, profs = pcall(function() return WowF.profesiones and WowF.profesiones() or {} end)
  return okP and type(profs) == "table" and #profs > 0 or false
end
-- 4-nov: la interfaz no se ve (combate, cinematica de entrada, UIParent oculto): la ventana espera en vez de perderse
function WowF.interfazOcupada()
  if InCombatLockdown and InCombatLockdown() then return true end
  if InCinematic and InCinematic() then return true end
  if UIParent and UIParent.IsShown and not UIParent:IsShown() then return true end
  return false
end

-- La primera vez: un momento despues de entrar al mundo (ya estan cargadas las variables guardadas)
local eventos = CreateFrame("Frame")
WowF.eventosBienvenida = eventos -- para las pruebas: el simulador entrega cada evento a todos los marcos; el juego, solo a los registrados
pcall(eventos.RegisterEvent, eventos, "ADDON_LOADED")
pcall(eventos.RegisterEvent, eventos, "PLAYER_ENTERING_WORLD")
eventos:SetScript("OnEvent", function(self, evento, nombre)
  if evento == "ADDON_LOADED" then
    if nombre == "ForeverLevelingGuide" then
      estabaVacia = dbVacia(WowFExportarDB)
      pcall(self.UnregisterEvent, self, "ADDON_LOADED")
    end
    return
  end
  pcall(self.UnregisterEvent, self, "PLAYER_ENTERING_WORLD")
  WowFExportarDB = WowFExportarDB or {}
  -- Ya rehecha antes (otro personaje de la cuenta entro primero): rehacer tambien lo de este, sin aviso
  if WowFExportarDB.rehecho then rehacerPersonaje() end
  if estabaVacia and not WowFExportarDB.bienvenida then
    if WowF.pjVeterano() then
      WowF.rehacerAjustes()
      return
    end
  end
  -- idiomaVisto: quien la vio antes de que existiera el paso de idioma la ve una vez mas
  if WowFExportarDB and WowFExportarDB.bienvenida and WowFExportarDB.idiomaVisto then return end
  -- 4-nov: en combate o con la interfaz oculta (cinematica de entrada) se reintenta cada 2 s (hasta ~3 min); antes se perdia
  local intentos = 0
  local function abrir()
    if WowFExportarDB.bienvenida and WowFExportarDB.idiomaVisto then return end
    if WowF.interfazOcupada() then
      intentos = intentos + 1
      if intentos <= 90 and C_Timer and C_Timer.After then C_Timer.After(2, abrir) end
      return
    end
    WowF.abrirBienvenida(1)
  end
  if C_Timer and C_Timer.After then C_Timer.After(4, abrir) else abrir() end
end)

-- /wowf ayuda (o help, bienvenida, inicio) la vuelve a abrir
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
  if orden == "ayuda" or orden == "help" or orden == "bienvenida" or orden == "inicio" or orden == "?" then
    WowF.abrirBienvenida(1)
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end
