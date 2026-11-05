-- wowF Guia: "Guia del addon" (13-oct, pedido de Andy: "como un mapa del addon para que sepa cada cosa que es lo que hace").
-- Ventana fija con temas a la izquierda y la explicacion a la derecha: donde esta cada cosa, para que sirve y como se usa
-- (ventanas, panel, boton del minimapa, plan completo y sus pestanas, mapa e iconos, rutas, avisos, ajustes, comandos y colores).
-- Se abre con el "?" del plan completo, el boton "Guia" de Ajustes, el ultimo paso de la bienvenida y /wowf guia|guide|manual.
-- Textos en los dos idiomas con L(es, en): no pasan por el diccionario. Sin UISpecialFrames nuevos de riesgo: solo la ventana propia.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local ORO, VERDE, GRIS, NARANJA, AZUL = "|cffffd100", "|cff33ff66", "|cff999999", "|cffff9933", "|cff66ccff"
local function cab(es, en) return ORO .. L(es, en) .. "|r\n" end
local function k(s) return VERDE .. s .. "|r" end

-- Cada tema: clave, titulo, icono y texto (se arman al mostrar: el idioma puede cambiar)
local function temas()
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  return {
    { "inicio", L("Cómo funciona", "How it works"), "Interface\\Icons\\INV_Misc_Book_09",
      L("Forever Guide arma un plan para TU personaje y lo va cambiando solo con tu nivel, tu clase, tu rama de talentos, tus profesiones, tu equipo, tu facción y el sitio donde estás. No hay que configurar nada.\n\n"
        .. cab("Lo verás en tres sitios", "")
        .. k("1. El panel") .. " (a la derecha): lo próximo que te toca.\n"
        .. k("2. El plan completo") .. " (botón del minimapa o /wowf): todo, por pestañas.\n"
        .. k("3. El mapa") .. ": rutas, entrenadores y misiones marcados.\n\n"
        .. cab("Datos", "")
        .. "Todo sale de WoW Forever (la beta llega hoy al nivel " .. tope .. "). Cuando algo aún no tiene datos de WoW Forever, la guía lo dice con un aviso " .. NARANJA .. "naranja|r y nunca lo inventa; se completa en próximas actualizaciones.\n\n"
        .. GRIS .. "Elige un tema a la izquierda para ver dónde está cada cosa y cómo se usa.|r",
        "Forever Guide builds a plan for YOUR character and keeps updating it with your level, class, talent spec, professions, gear, faction and where you are. Nothing to set up.\n\n"
        .. ORO .. "You will see it in three places|r\n"
        .. k("1. The panel") .. " (on the right): what's next for you.\n"
        .. k("2. The full plan") .. " (minimap button or /wowf): everything, in tabs.\n"
        .. k("3. The map") .. ": routes, trainers and quests marked.\n\n"
        .. ORO .. "Data|r\n"
        .. "Everything comes from WoW Forever (the beta currently goes up to level " .. tope .. "). When something has no WoW Forever data yet, the guide says so with an " .. NARANJA .. "orange|r notice and never makes it up; it gets filled in future updates.\n\n"
        .. GRIS .. "Pick a topic on the left to see where each thing is and how to use it.|r") },

    { "ventanas", L("Ventanas", "Windows"), "Interface\\Icons\\INV_Misc_Note_02",
      L(cab("Mover", "") .. "Todas las ventanas se mueven arrastrándolas con el clic izquierdo (el plan completo, por el estandarte o el borde). La ventana de la ruta, la de la línea de misiones, el aviso de botín y el probador recuerdan dónde las dejaste.\n\n"
        .. cab("Cerrar", "") .. "Con la " .. k("X") .. " de arriba a la derecha. La tecla " .. k("Esc") .. " cierra el plan completo, Ajustes, Novedades, la bienvenida y esta guía.\n"
        .. "El panel no se cierra: se " .. k("pliega") .. " con su botón " .. k("–") .. " o se oculta con " .. k("Mayús + clic derecho") .. " en el botón del minimapa (o /wowf panel).\n"
        .. "El aviso de botín: " .. k("Cerrar") .. " quita ese, " .. k("Siguiente") .. " pasa al próximo y la X los quita todos.\n\n"
        .. cab("Tamaño, letra y fondo", "") .. "En " .. k("Ajustes") .. ": tamaño de las ventanas (70-150 %), tamaño de letra y opacidad del fondo. " .. k("Restablecer") .. " lo deja como venía.",
        ORO .. "Move|r\nEvery window moves by dragging it with left-click (the full plan, by the banner or the border). The route window, the questline window, the loot alert and the preview window remember where you left them.\n\n"
        .. ORO .. "Close|r\nWith the " .. k("X") .. " at the top right. The " .. k("Esc") .. " key closes the full plan, Settings, What's new, the welcome and this guide.\n"
        .. "The panel doesn't close: you " .. k("fold") .. " it with its " .. k("–") .. " button or hide it with " .. k("Shift + right-click") .. " on the minimap button (or /wowf panel).\n"
        .. "The loot alert: " .. k("Close") .. " removes that one, " .. k("Next") .. " shows the next one and the X removes them all.\n\n"
        .. ORO .. "Size, text and background|r\nIn " .. k("Settings") .. ": window size (70-150 %), text size and background opacity. " .. k("Reset") .. " puts everything back to default.") },

    { "panel", L("El panel", "The panel"), "Interface\\Icons\\INV_Misc_Map_01",
      L(cab("Dónde está", "") .. "A la derecha de la pantalla, con tu retrato y tu nivel arriba.\n\n"
        .. cab("Para qué sirve", "") .. "Te dice lo PRÓXIMO: a qué zona ir, qué mazmorra te toca, qué aprender, qué pieza buscar y qué fabricar. Haz clic en una línea y te pone la ruta o el alfiler en el mapa.\n\n"
        .. cab("Cómo se usa", "")
        .. "• Arrástralo para moverlo.\n"
        .. "• " .. k("–") .. " lo pliega y lo despliega.\n"
        .. "• El " .. k("engranaje") .. " abre Ajustes.\n"
        .. "• " .. k("Plan completo") .. " abre el libro con todas las pestañas.\n"
        .. "• Ocultarlo o mostrarlo: " .. k("Mayús + clic derecho") .. " en el botón del minimapa, o /wowf panel.",
        ORO .. "Where it is|r\nOn the right side of the screen, with your portrait and level at the top.\n\n"
        .. ORO .. "What it's for|r\nIt shows what's NEXT: which zone to go to, which dungeon is yours, what to learn, which item to look for and what to craft. Click a line and it sets the route or the pin on the map.\n\n"
        .. ORO .. "How to use it|r\n"
        .. "• Drag it to move it.\n"
        .. "• " .. k("–") .. " folds and unfolds it.\n"
        .. "• The " .. k("gear") .. " opens Settings.\n"
        .. "• " .. k("Full plan") .. " opens the book with every tab.\n"
        .. "• Hide or show it: " .. k("Shift + right-click") .. " on the minimap button, or /wowf panel.") },

    { "minimapa", L("Botón del minimapa", "Minimap button"), "Interface\\Icons\\INV_Misc_Book_09",
      L(cab("Dónde está", "") .. "El botón redondo con el libro, en el borde del minimapa.\n\n"
        .. cab("Cómo se usa", "")
        .. k("Clic") .. ": abre o cierra tu plan completo.\n"
        .. k("Clic derecho") .. ": el diario de la mazmorra que te toca.\n"
        .. k("Mayús + clic derecho") .. ": muestra u oculta el panel.\n"
        .. k("Arrastrar") .. ": lo mueves alrededor del minimapa.\n\n"
        .. cab("¿Te estorba?", "") .. "En Ajustes está la casilla " .. k("Ocultar el botón del minimapa") .. ". Sin el botón, /wowf sigue abriendo la guía.",
        ORO .. "Where it is|r\nThe round button with the book, on the edge of the minimap.\n\n"
        .. ORO .. "How to use it|r\n"
        .. k("Click") .. ": opens or closes your full plan.\n"
        .. k("Right-click") .. ": the journal of the dungeon that is right for you.\n"
        .. k("Shift + right-click") .. ": shows or hides the panel.\n"
        .. k("Drag") .. ": moves it around the minimap.\n\n"
        .. ORO .. "In your way?|r\nSettings has the " .. k("Hide the minimap button") .. " checkbox. Without the button, /wowf still opens the guide.") },

    { "libro", L("Plan completo", "Full plan"), "Interface\\Icons\\INV_Misc_Note_01",
      L(cab("Cómo se abre", "") .. "Clic en el botón del minimapa, " .. k("Plan completo") .. " en el panel o /wowf.\n\n"
        .. cab("Pestañas", "")
        .. k("Progreso") .. ": qué te toca en cada nivel y dónde subir.\n"
        .. k("Talentos") .. ": dónde va cada punto, en orden, según la guía de tu rama.\n"
        .. k("Combate") .. ": rotación (PvE y PvP) y macros que se crean con un clic.\n"
        .. k("Profesiones") .. ": cuáles coger y cómo subirlas, paso a paso.\n"
        .. k("Equipo") .. ": las piezas que te tocan y de dónde salen.\n"
        .. k("Mazmorras") .. ": el diario de cada mazmorra.\n"
        .. k("BiS 30") .. ": lo mejor para tu rama al nivel " .. tope .. ", mascota y consumibles.\n\n"
        .. cab("Columna de la izquierda", "")
        .. k("English/Español") .. ": cambia el idioma al momento.\n"
        .. k("Ajustes") .. ": tamaño, avisos e iconos.\n"
        .. "Iconos chicos: " .. k("Novedades") .. ", " .. k("?") .. " (esta guía) y tu entrenador de clase.\n"
        .. k("Limpiar el mapa") .. ": sale cuando hay una ruta o marcas puestas.\n\n"
        .. GRIS .. "Se mueve arrastrando el estandarte o el borde; se cierra con la X o Esc.|r",
        ORO .. "How to open it|r\nClick the minimap button, " .. k("Full plan") .. " on the panel, or /wowf.\n\n"
        .. ORO .. "Tabs|r\n"
        .. k("Progress") .. ": what to do at each level and where to level.\n"
        .. k("Talents") .. ": where each point goes, in order, following your spec's guide.\n"
        .. k("Combat") .. ": rotation (PvE and PvP) and macros created with one click.\n"
        .. k("Professions") .. ": which ones to pick and how to level them, step by step.\n"
        .. k("Gear") .. ": the items for you and where they come from.\n"
        .. k("Dungeons") .. ": the journal of each dungeon.\n"
        .. k("BiS 30") .. ": the best for your spec at level " .. tope .. ", pet and consumables.\n\n"
        .. ORO .. "Left column|r\n"
        .. k("English/Español") .. ": switches the language right away.\n"
        .. k("Settings") .. ": size, alerts and icons.\n"
        .. "Small icons: " .. k("What's new") .. ", " .. k("?") .. " (this guide) and your class trainer.\n"
        .. k("Clear the map") .. ": shows up when a route or marks are set.\n\n"
        .. GRIS .. "Move it by dragging the banner or the border; close it with the X or Esc.|r") },

    { "talentos", L("Progreso y talentos", "Progress and talents"), "Interface\\Icons\\Ability_Marksmanship",
      L(cab("Progreso", "") .. "Tu plan nivel a nivel: zonas encadenadas para subir, mazmorras, entrenador y lo que se desbloquea. " .. k("Rehacer") .. " lo vuelve a calcular con tu personaje de ahora.\n\n"
        .. cab("Talentos", "") .. "El árbol como en el juego, con el número de cada punto en el orden de la guía de tu rama (la fuente sale abajo, con su enlace para copiar).\n"
        .. k("Verde") .. " = el siguiente punto · " .. ORO .. "Dorado|r = ya puesto · " .. NARANJA .. "Naranja|r = sin guía verificada.\n"
        .. "Si pusiste puntos fuera del orden, te avisa arriba.\n\n"
        .. cab("Tu rama", "") .. "Sale sola de tus talentos. Arriba de la pestaña: " .. k("Cambiar de rama") .. " (o /wowf rama). Si tu plan cambia de rama a cierto nivel, verás los dos tramos.",
        ORO .. "Progress|r\nYour plan level by level: chained zones to level in, dungeons, trainer and what unlocks. " .. k("Rebuild") .. " recalculates it with your character as it is now.\n\n"
        .. ORO .. "Talents|r\nThe tree like in the game, with the number of each point in the order of your spec's guide (the source is shown below, with a link to copy).\n"
        .. k("Green") .. " = next point · " .. ORO .. "Gold|r = already spent · " .. NARANJA .. "Orange|r = no verified guide.\n"
        .. "If you spent points out of order, it warns you at the top.\n\n"
        .. ORO .. "Your spec|r\nIt comes from your talents. At the top of the tab: " .. k("Change spec") .. " (or /wowf spec). If your plan switches spec at some level, you'll see both parts.") },

    { "combate", L("Rotación y macros", "Rotation and macros"), "Interface\\Icons\\Ability_Warrior_Charge",
      L(cab("Rotación", "") .. "Qué golpes usar y en qué orden, para tu rama y tu nivel. Cambia entre " .. k("PvE") .. " y " .. k("PvP") .. " arriba. Si te falta un hechizo, dice cómo conseguirlo (entrenador, talento o misión de clase).\n\n"
        .. cab("Macros", "") .. "Un clic y la macro se crea sola. Cada una dice para qué sirve y cuándo usarla, y si vale en PvE, en PvP o en los dos.\n"
        .. NARANJA .. "Naranja|r = te falta algo: haz clic y te lleva a tu entrenador.\n"
        .. "Cuando aprendes algo nuevo, la macro se rehace sola y te avisa.",
        ORO .. "Rotation|r\nWhich abilities to use and in what order, for your spec and level. Switch between " .. k("PvE") .. " and " .. k("PvP") .. " at the top. If you're missing a spell, it says how to get it (trainer, talent or class quest).\n\n"
        .. ORO .. "Macros|r\nOne click and the macro is created. Each one says what it's for and when to use it, and whether it works in PvE, PvP or both.\n"
        .. NARANJA .. "Orange|r = something is missing: click it and it takes you to your trainer.\n"
        .. "When you learn something new, the macro rebuilds itself and lets you know.") },

    { "profesiones", L("Profesiones", "Professions"), "Interface\\Icons\\Trade_BlackSmithing",
      L(cab("Objetivo", "") .. "Al principio eliges para qué quieres tus profesiones: " .. k("vender") .. " (oro), " .. k("fabricarte equipo") .. " o " .. k("PvP") .. ". Se cambia cuando quieras (/wowf objetivo).\n\n"
        .. cab("Sub-pestañas", "")
        .. k("Mis profesiones") .. ": lo que ya puedes hacer y lo próximo al subir.\n"
        .. k("Para vender / Fabricarte equipo / Para PvP") .. ": según tu objetivo.\n"
        .. k("Secundarias") .. ": Cooking, First Aid y Fishing (con dónde pescar).\n"
        .. k("Cajas y favor") .. ": Waylaid Crates y Merchant's Favor.\n"
        .. k("Legacy") .. " y " .. k("Más") .. ": el resto.\n\n"
        .. cab("En el mapa", "") .. "Clic en un paso = alfiler al entrenador. Para las profesiones que se suben matando (Skinning, Leatherworking, Tailoring, Cooking...) te marca el área de mobs más cercana con un círculo verde.",
        ORO .. "Goal|r\nAt the start you choose what your professions are for: " .. k("selling") .. " (gold), " .. k("crafting your gear") .. " or " .. k("PvP") .. ". Change it any time (/wowf goal).\n\n"
        .. ORO .. "Sub-tabs|r\n"
        .. k("My professions") .. ": what you can do now and what's next as you level.\n"
        .. k("To sell / Craft your gear / For PvP") .. ": based on your goal.\n"
        .. k("Secondary") .. ": Cooking, First Aid and Fishing (with where to fish).\n"
        .. k("Crates & Favor") .. ": Waylaid Crates and Merchant's Favor.\n"
        .. k("Legacy") .. " and " .. k("More") .. ": the rest.\n\n"
        .. ORO .. "On the map|r\nClick a step = pin on the trainer. For professions leveled by killing mobs (Skinning, Leatherworking, Tailoring, Cooking...) it marks the closest mob area with a green circle.") },

    { "equipo", L("Equipo y BiS 30", "Gear and BiS 30"), "Interface\\Icons\\INV_Chest_Chain",
      L(cab("Equipo", "") .. "Tu personaje en 3D, una puntuación de 0 a 100 y, por cada hueco, la mejor pieza que puedes conseguir AHORA y de dónde sale.\n"
        .. "• Filtros: " .. k("Todo") .. ", " .. k("Misiones") .. ", " .. k("Mazmorras") .. ", " .. k("Fabricar") .. ", " .. k("Comprar") .. ".\n"
        .. "• " .. k("Ver otras opciones") .. " en cada hueco.\n"
        .. "• " .. k("Anotar") .. ": la pieza entra en tu lista de \"Piezas que buscas\".\n"
        .. "• Clic en una pieza = ruta a la misión, la mazmorra o el vendedor.\n\n"
        .. cab("BiS 30", "") .. "Lo mejor para tu rama al nivel " .. tope .. " (pre-BiS incluido), con clic en cada pieza para ir a buscarla. Más abajo: " .. k("Mascota") .. " (Hunter y Warlock) y " .. k("Consumibles") .. " para PvE y PvP.",
        ORO .. "Gear|r\nYour character in 3D, a score from 0 to 100 and, for each slot, the best item you can get NOW and where it comes from.\n"
        .. "• Filters: " .. k("All") .. ", " .. k("Quests") .. ", " .. k("Dungeons") .. ", " .. k("Craft") .. ", " .. k("Buy") .. ".\n"
        .. "• " .. k("See other options") .. " on each slot.\n"
        .. "• " .. k("Track") .. ": the item goes into your \"Items you're looking for\" list.\n"
        .. "• Click an item = route to the quest, the dungeon or the vendor.\n\n"
        .. ORO .. "BiS 30|r\nThe best for your spec at level " .. tope .. " (pre-BiS included), with a click on each item to go get it. Further down: " .. k("Pet") .. " (Hunter and Warlock) and " .. k("Consumables") .. " for PvE and PvP.") },

    { "mazmorras", L("Mazmorras (diario)", "Dungeons (journal)"), "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      L(cab("Dónde está", "") .. "Pestaña " .. k("Mazmorras") .. " del plan, o " .. k("clic derecho") .. " en el botón del minimapa (abre la que te toca).\n\n"
        .. cab("La lista", "") .. "\"Puedes ir ya\" y \"Más adelante\", con las que te recomiendan arriba.\n\n"
        .. cab("La ficha de cada mazmorra", "")
        .. k("Resumen") .. ": nivel, dónde está y cómo llegar.\n"
        .. k("Jefes y botín") .. ": lo que suelta cada jefe para ti. " .. k("Ctrl + clic") .. " = probártelo, " .. k("Mayús + clic") .. " = enlazarlo en el chat.\n"
        .. k("Misiones") .. ": quién las da (fuera o dentro) y a quién se entregan.\n"
        .. k("Ruta") .. ": lo que te falta para ir, paso a paso.\n"
        .. k("Mapa") .. ": los jefes numerados en orden y lo básico de cada pelea. Se puede sacar a una ventana pequeña (/wowf sacarmapa).\n\n"
        .. GRIS .. "Dentro de la mazmorra, el jefe que suelta tu pieza sale marcado: \"PUEDE SOLTAR TU PIEZA\".|r",
        ORO .. "Where it is|r\nThe " .. k("Dungeons") .. " tab of the plan, or " .. k("right-click") .. " on the minimap button (opens the one that is right for you).\n\n"
        .. ORO .. "The list|r\n\"You can go now\" and \"Later on\", with the recommended ones on top.\n\n"
        .. ORO .. "Each dungeon's page|r\n"
        .. k("Overview") .. ": level, where it is and how to get there.\n"
        .. k("Bosses and loot") .. ": what each boss drops for you. " .. k("Ctrl + click") .. " = try it on, " .. k("Shift + click") .. " = link it in chat.\n"
        .. k("Quests") .. ": who gives them (outside or inside) and where to turn them in.\n"
        .. k("Path") .. ": what you still need to go, step by step.\n"
        .. k("Map") .. ": bosses numbered in order and the basics of each fight. It can pop out to a small window (/wowf popout).\n\n"
        .. GRIS .. "Inside the dungeon, the boss that drops your item is marked: \"CAN DROP YOUR ITEM\".|r") },

    { "mapa", L("Mapa e iconos", "Map and icons"), "Interface\\Icons\\INV_Misc_Map02",
      L(cab("Iconos de entrenadores de profesiones", "")
        .. "Tres modos: " .. k("mías") .. " (tus profesiones y las de tu plan), " .. k("todas") .. " o " .. k("ninguna") .. ". Se cambia con el botón de abajo a la izquierda del mapa (tecla M), en Ajustes o con /wowf entrenadores mias|todas|ninguna.\n"
        .. "¿Muy grandes o muy fuertes? En " .. k("Ajustes") .. ": " .. k("Tamaño de los iconos") .. " y " .. k("Opacidad de los iconos") .. " (se ven al momento).\n\n"
        .. cab("Lo demás que verás", "")
        .. "• " .. "|cffcc66ff!|r morado: misión de mazmorra que se recoge FUERA. Clic = alfiler y ruta.\n"
        .. "• Círculos numerados unidos por una raya: tu ruta (" .. k("verde") .. " = el que toca).\n"
        .. "• Círculo verde grande: área de mobs para tu profesión.\n"
        .. "• Icono de tu entrenador de clase.\n\n"
        .. cab("Quitarlo todo", "") .. "Botón " .. k("Limpiar el mapa") .. " del plan completo.",
        ORO .. "Profession trainer icons|r\n"
        .. "Three modes: " .. k("mine") .. " (your professions and the ones in your plan), " .. k("all") .. " or " .. k("none") .. ". Change it with the button at the bottom left of the map (M key), in Settings or with /wowf trainers mine|all|none.\n"
        .. "Too big or too strong? In " .. k("Settings") .. ": " .. k("Trainer icon size") .. " and " .. k("Trainer icon opacity") .. " (you see it right away).\n\n"
        .. ORO .. "Everything else you'll see|r\n"
        .. "• Purple |cffcc66ff!|r: a dungeon quest you pick up OUTSIDE. Click = pin and route.\n"
        .. "• Numbered circles joined by a line: your route (" .. k("green") .. " = the current one).\n"
        .. "• Big green circle: mob area for your profession.\n"
        .. "• Your class trainer's icon.\n\n"
        .. ORO .. "Remove it all|r\nThe " .. k("Clear the map") .. " button in the full plan.") },

    { "rutas", L("Rutas, flecha y marcas", "Routes, arrow and marks"), "Interface\\Icons\\Ability_Tracking",
      L(cab("La ruta", "") .. "Al hacer clic en una mazmorra, una misión o una pieza, sale un recuadro con " .. k("PASO 1 DE N") .. ", qué hacer y hacia dónde ir, con un alfiler azul en el mapa. Avanza solo al llegar y se rehace si te desvías.\n"
        .. "• Se mueve arrastrándolo; la X lo quita.\n"
        .. "• " .. k("Marcar la ruta en el mapa") .. ": la dibuja entera.\n"
        .. "• La " .. k("flecha") .. " bajo el minimapa apunta al siguiente punto.\n"
        .. "• Parar todo: /wowf parar.\n\n"
        .. cab("Líneas de misiones", "") .. "Una ventana aparte con la línea completa (AHORA en verde, la importante en morado) que avanza sola. Se minimiza; " .. k("Quitar la línea") .. " la cierra. /wowf linea la vuelve a abrir.\n\n"
        .. cab("Marca sobre el NPC", "") .. "Un " .. k("!") .. " grande con \"HABLA AQUÍ\" sobre el NPC al que te manda la guía. /wowf marca on|off.",
        ORO .. "The route|r\nWhen you click a dungeon, a quest or an item, a box shows up with " .. k("STEP 1 OF N") .. ", what to do and which way to go, with a blue pin on the map. It moves on by itself when you arrive and rebuilds if you go off track.\n"
        .. "• Drag it to move it; the X removes it.\n"
        .. "• " .. k("Mark the route on the map") .. ": draws the whole thing.\n"
        .. "• The " .. k("arrow") .. " under the minimap points to the next spot.\n"
        .. "• Stop everything: /wowf stop.\n\n"
        .. ORO .. "Questlines|r\nA separate window with the whole line (NOW in green, the important one in purple) that moves on by itself. It can be minimized; " .. k("Remove the line") .. " closes it. /wowf questline opens it again.\n\n"
        .. ORO .. "Mark on the NPC|r\nA big " .. k("!") .. " with \"TALK HERE\" over the NPC the guide sends you to. /wowf mark on|off.") },

    { "avisos", L("Avisos", "Alerts"), "Interface\\Icons\\INV_Misc_Bag_10",
      L("Todos se apagan o encienden en " .. k("Ajustes") .. ".\n\n"
        .. k("Al subir de nivel") .. ": hechizos nuevos del entrenador, piezas que vale la pena fabricar y mazmorras nuevas. Casilla " .. k("Ventanas al subir de nivel") .. ": apagada, el resumen sale solo en el chat.\n\n"
        .. k("Botín") .. ": verde = te sirve (guárdalo), " .. ORO .. "dorado|r = vale oro, " .. AZUL .. "azul|r = guárdalo para tu rama final. /wowf avisobotin on|off.\n\n"
        .. k("Bolsas") .. ": solo al entrar al juego y si te quedan 2 huecos o menos.\n"
        .. k("Equipo roto") .. ": si la durabilidad baja del 20 %.\n"
        .. k("Habilidad de arma") .. ": si va baja.\n"
        .. k("Misiones de grupo") .. ": te avisa antes de aceptarlas.\n"
        .. k("Entrenador de clase") .. ": si te alcanza el oro.\n"
        .. k("Recompensa de misión") .. ": marca la mejor para ti.\n"
        .. k("Tooltip") .. ": al pasar el ratón por un objeto, si te mejora.\n"
        .. k("Vendedor") .. ": lista de lo que puedes vender (y reparar todo, si lo enciendes).",
        "All of them can be turned on or off in " .. k("Settings") .. ".\n\n"
        .. k("On level up") .. ": new trainer spells, items worth crafting and new dungeons. " .. k("Level-up popups") .. " checkbox: off, the summary only goes to chat.\n\n"
        .. k("Loot") .. ": green = useful for you (keep it), " .. ORO .. "gold|r = worth gold, " .. AZUL .. "blue|r = save it for your final spec. /wowf lootalert on|off.\n\n"
        .. k("Bags") .. ": only when you log in and only with 2 free slots or fewer.\n"
        .. k("Broken gear") .. ": when durability drops below 20 %.\n"
        .. k("Weapon skill") .. ": when it's low.\n"
        .. k("Group quests") .. ": warns you before you accept them.\n"
        .. k("Class trainer") .. ": whether you can afford training.\n"
        .. k("Quest reward") .. ": highlights the best one for you.\n"
        .. k("Tooltip") .. ": when you hover an item, whether it's an upgrade.\n"
        .. k("Vendor") .. ": list of what you can sell (and repair all, if you turn it on).") },

    { "ajustes", L("Ajustes", "Settings"), "Interface\\Icons\\INV_Misc_Gear_01",
      L(cab("Cómo se abre", "") .. "Botón " .. k("Ajustes") .. " del plan completo, el " .. k("engranaje") .. " del panel, Opciones > AddOns del juego o /wowf ajustes.\n\n"
        .. cab("Qué hay", "")
        .. k("Ventanas") .. ": tamaño (70-150 %), opacidad del fondo y tamaño de letra.\n"
        .. k("Avisos y mejoras") .. ": una casilla por cada aviso, los filtros de mejoras (misiones, mazmorras, fabricadas) y ocultar el botón del minimapa.\n"
        .. k("Abrir el plan en") .. ": la pestaña con la que se abre.\n"
        .. k("Mapa") .. ": modo de los iconos de entrenadores, su tamaño y su opacidad.\n\n"
        .. k("Restablecer") .. " deja tamaño, letra, fondo e iconos como venían. Todo se guarda solo.",
        ORO .. "How to open it|r\nThe " .. k("Settings") .. " button in the full plan, the " .. k("gear") .. " on the panel, the game's Options > AddOns, or /wowf settings.\n\n"
        .. ORO .. "What's in it|r\n"
        .. k("Windows") .. ": size (70-150 %), background opacity and text size.\n"
        .. k("Alerts and upgrades") .. ": one checkbox per alert, the upgrade filters (quests, dungeons, crafted) and hiding the minimap button.\n"
        .. k("Open the plan on") .. ": the tab it opens on.\n"
        .. k("Map") .. ": trainer icon mode, size and opacity.\n\n"
        .. k("Reset") .. " puts size, text, background and icons back to default. Everything saves by itself.") },

    { "comandos", L("Comandos", "Commands"), "Interface\\Icons\\INV_Misc_Note_06",
      L("Escríbelos en el chat:\n\n"
        .. k("/wowf") .. "  abre o cierra tu plan completo\n"
        .. k("/wowf guia") .. "  esta guía\n"
        .. k("/wowf ayuda") .. "  la bienvenida otra vez\n"
        .. k("/wowf ajustes") .. "  ajustes\n"
        .. k("/wowf panel") .. "  muestra u oculta el panel\n"
        .. k("/wowf idioma") .. "  cambia el idioma\n"
        .. k("/wowf novedades") .. "  lo nuevo de esta versión\n"
        .. k("/wowf rama") .. "  cambiar de rama\n"
        .. k("/wowf objetivo fabricar|oro|pvp") .. "  objetivo de profesiones\n"
        .. k("/wowf mazmorras") .. "  mazmorras para tu nivel\n"
        .. k("/wowf ruta <mazmorra>") .. "  ruta a una mazmorra\n"
        .. k("/wowf parar") .. "  quita la ruta\n"
        .. k("/wowf entrenadores mias|todas|ninguna") .. "  iconos del mapa\n"
        .. k("/wowf avisobotin on|off") .. "  aviso de botín\n"
        .. k("/wowf marca on|off") .. "  marca sobre el NPC\n"
        .. k("/wowf bis") .. "  · " .. k("/wowf consumibles") .. "  · " .. k("/wowf cajas") .. "  · " .. k("/wowf favor") .. "\n"
        .. k("/wowf errores") .. "  código para reportar un error\n\n"
        .. GRIS .. "También sirven /flg y /forever.|r",
        "Type them in chat:\n\n"
        .. k("/wowf") .. "  opens or closes your full plan\n"
        .. k("/wowf guide") .. "  this guide\n"
        .. k("/wowf help") .. "  the welcome again\n"
        .. k("/wowf settings") .. "  settings\n"
        .. k("/wowf panel") .. "  shows or hides the panel\n"
        .. k("/wowf language") .. "  changes the language\n"
        .. k("/wowf changes") .. "  what's new in this version\n"
        .. k("/wowf spec") .. "  change spec\n"
        .. k("/wowf goal craft|gold|pvp") .. "  professions goal\n"
        .. k("/wowf dungeons") .. "  dungeons for your level\n"
        .. k("/wowf route <dungeon>") .. "  route to a dungeon\n"
        .. k("/wowf stop") .. "  removes the route\n"
        .. k("/wowf trainers mine|all|none") .. "  map icons\n"
        .. k("/wowf lootalert on|off") .. "  loot alert\n"
        .. k("/wowf mark on|off") .. "  mark on the NPC\n"
        .. k("/wowf bis") .. "  · " .. k("/wowf consumables") .. "  · " .. k("/wowf crates") .. "  · " .. k("/wowf merchant") .. "\n"
        .. k("/wowf errors") .. "  code to report an error\n\n"
        .. GRIS .. "/flg and /forever work too.|r") },

    { "colores", L("Los colores", "The colors"), "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
      L(k("Verde") .. " = ya puedes hacerlo, o haz clic ahí.\n"
        .. ORO .. "Dorado|r = lo tendrás más adelante (o ya lo tienes puesto).\n"
        .. NARANJA .. "Naranja|r = te falta algo, o aún no hay datos de WoW Forever.\n"
        .. AZUL .. "Azul|r = guárdalo para tu rama final.\n"
        .. "|cffcc66ffMorado|r = misión de mazmorra.\n"
        .. GRIS .. "Gris|r = solo información.\n\n"
        .. "Pasa el ratón por casi cualquier cosa: el tooltip explica qué es y qué pasa al hacer clic.",
        k("Green") .. " = you can do it now, or click it.\n"
        .. ORO .. "Gold|r = you'll get it later (or you already have it).\n"
        .. NARANJA .. "Orange|r = something is missing, or there's no WoW Forever data yet.\n"
        .. AZUL .. "Blue|r = save it for your final spec.\n"
        .. "|cffcc66ffPurple|r = dungeon quest.\n"
        .. GRIS .. "Gray|r = information only.\n\n"
        .. "Hover over almost anything: the tooltip explains what it is and what clicking does.") },
  }
end
WowF.guiaTemas = temas

-- ===================== Ventana =====================
local ANCHO, ALTO, IZQ_LISTA = 680, 500, 196
local v, titulo, icono, cuerpo, hijo, desliz, actual
local botones = {}

local function pintar()
  local T = temas()
  local elegido = T[1]
  for _, t in ipairs(T) do if t[1] == actual then elegido = t end end
  actual = elegido[1]
  local E = WowF.estilo
  titulo:SetText(elegido[2])
  icono:SetTexture(elegido[3])
  local txt = tostring(elegido[4] or "")
  if E and E.cod then txt = txt:gsub(ORO, E.cod.oro):gsub(GRIS, E.cod.tenue) end
  cuerpo:SetText(txt)
  local alto = tonumber(cuerpo.GetStringHeight and cuerpo:GetStringHeight()) or 0
  hijo:SetHeight(math.max(200, alto + 20))
  if desliz.SetVerticalScroll then pcall(desliz.SetVerticalScroll, desliz, 0) end
  for i, t in ipairs(T) do
    local b = botones[i]
    if b then
      b:SetText(t[2])
      if E and E.boton then E.boton(b, t[1] == actual and "brasa" or "cuero", 12) end
      b:Show()
    end
  end
  v.cab:SetText((E and E.cod and E.cod.oro or ORO) .. "Forever Guide|r - " .. L("Guía del addon", "Addon guide"))
end

local function crear()
  if v then return v end
  local E = WowF.estilo
  v = CreateFrame("Frame", "wowFGuia", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(ANCHO, ALTO)
  v:SetPoint("CENTER", 0, 40)
  v:SetFrameStrata("DIALOG")
  v:SetClampedToScreen(true)
  v:SetMovable(true)
  v:EnableMouse(true)
  v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", v.StartMoving)
  v:SetScript("OnDragStop", v.StopMovingOrSizing)
  if v.SetBackdrop then
    v:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    v:SetBackdropColor(0.03, 0.03, 0.05, 0.96)
    v:SetBackdropBorderColor(1, 0.82, 0, 0.9)
  end
  E.marco(v, "tapa")
  v.cab = E.titulo(v, nil, 16)
  v.cab:SetPoint("TOPLEFT", 24, -22)
  local x = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(x, "cuero", 11)
  x:SetSize(18, 18)
  x:SetText("X")
  x:SetPoint("TOPRIGHT", -16, -18)
  x:SetScript("OnClick", function() v:Hide() end)
  v.x = x
  E.divisor(v, nil, -50, 22, 22)
  -- Lista de temas (izquierda)
  for i = 1, 20 do
    local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
    E.boton(b, "cuero", 12)
    b:SetSize(IZQ_LISTA - 30, 24)
    b:SetPoint("TOPLEFT", 22, -60 - (i - 1) * 27)
    b:SetScript("OnClick", function() local T = temas(); if T[i] then actual = T[i][1]; pintar() end end)
    b:Hide()
    botones[i] = b
  end
  -- Tema (derecha): icono, titulo y texto con desplazamiento
  local casilla = E.textura and E.textura(v, "ARTWORK", 1, E.color.borde, 1) or v:CreateTexture(nil, "ARTWORK", nil, 1)
  casilla:SetSize(40, 40)
  casilla:SetPoint("TOPLEFT", IZQ_LISTA, -62)
  icono = v:CreateTexture(nil, "ARTWORK", nil, 3)
  icono:SetSize(36, 36)
  icono:SetPoint("CENTER", casilla, "CENTER")
  if icono.SetTexCoord then icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  titulo = E.titulo(v, nil, 18)
  titulo:SetPoint("LEFT", casilla, "RIGHT", 12, 0)
  titulo:SetPoint("RIGHT", v, "RIGHT", -30, 0)
  titulo:SetJustifyH("LEFT")
  desliz = CreateFrame("ScrollFrame", nil, v, "UIPanelScrollFrameTemplate")
  desliz:SetPoint("TOPLEFT", IZQ_LISTA, -114)
  desliz:SetPoint("BOTTOMRIGHT", -40, 24)
  hijo = CreateFrame("Frame", nil, desliz)
  local anchoTexto = ANCHO - IZQ_LISTA - 50
  hijo:SetSize(anchoTexto, 200)
  cuerpo = E.cuerpo(hijo, nil, 12)
  cuerpo:SetPoint("TOPLEFT", 0, 0)
  cuerpo:SetWidth(anchoTexto)
  cuerpo:SetJustifyH("LEFT")
  if cuerpo.SetJustifyV then cuerpo:SetJustifyV("TOP") end
  if cuerpo.SetSpacing then cuerpo:SetSpacing(3) end
  desliz:SetScrollChild(hijo)
  v:Hide()
  WowF.cerrarConEsc("wowFGuia") -- Esc la cierra (como Ajustes y Novedades)
  return v
end

-- Abre la guia en un tema (clave de temas(); sin tema, el ultimo visto o "Como funciona")
function WowF.abrirGuia(tema)
  crear()
  if tema then actual = tema end
  pintar()
  if WowF.opciones and v.SetScale then pcall(v.SetScale, v, WowF.escalaVentana and WowF.escalaVentana("wowFGuia") or WowF.opciones().tamano) end
  v:Show()
  return v
end
function WowF.cerrarGuia() if v then v:Hide() end end

-- Si cambia el idioma con la ventana abierta, se redibuja
local reidiomarAntes = WowF.reidiomar
WowF.reidiomar = function(...)
  if reidiomarAntes then reidiomarAntes(...) end
  if v and v:IsShown() then pcall(pintar) end
end

-- Para las pruebas: lo que se ve y clic en un tema por numero
function WowF.guiaEstado()
  local lista = {}
  for _, b in ipairs(botones) do if b:IsShown() then lista[#lista + 1] = b:GetText() or "" end end
  return { abierta = v ~= nil and v:IsShown() or false, tema = actual, titulo = v and titulo:GetText() or "", texto = v and cuerpo:GetText() or "",
    lista = lista, clic = function(i) local fn = botones[i] and botones[i]:GetScript("OnClick"); if fn then fn(botones[i]) end end }
end

-- ----- /wowf guia | guide | manual | mapaaddon -----
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(mensaje, ...)
    local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
    if orden == "guia" or orden == "guía" or orden == "guide" or orden == "manual" or orden == "mapaaddon" then
      if v and v:IsShown() then v:Hide() else WowF.abrirGuia() end
      return
    end
    if ordenAnterior then return ordenAnterior(mensaje, ...) end
  end
end
