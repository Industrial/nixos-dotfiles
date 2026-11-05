-- GENERADO por herramientas/generar-mecanicas.mjs desde herramientas/fuente/mecanicas-jefes.json (no editar).
-- Mecanicas minimas de cada jefe y datos de valor de la mazmorra. Fuente: guias de mazmorra de Icy Veins /wow-forever (solo WoW Forever).
-- [id de instancia] = { url, datos = { {es, en} }, jefes = { [encounterID] = { {es, en} } }, nombres = { ["Jefe"] = encounterID } }
WowFMecanicas = {
  [33] = { -- shadowfang-keep
    url = "https://www.icy-veins.com/wow-forever/shadowfang-keep-guide",
    datos = {
      { "Mazmorra para nivel 20-30, en Silverpine Forest, subiendo la rampa cerca de Greymane Wall (al sur).", "Level 20-30 dungeon in Silverpine Forest, up the ramp near the Greymane Wall to the south." },
      { "Para Alliance queda lejos: barco de Menethil Harbor a Southshore y una larga caminata.", "Far for Alliance: boat from Menethil Harbor to Southshore and a long walk." },
      { "Tiene 6 misiones: 3 de clases concretas y 3 solo de Horde.", "It has 6 quests: 3 class-specific and 3 Horde-only." },
      { "Salas pequeñas y cerradas: cuidado con atraer patrullas de más.", "Small, close-quarters rooms: be careful not to pull extra patrols." },
    },
    jefes = {
      [2748] = { -- Rethilgore
        { "Interrumpe su Soul Drain (le quita vida al tanque).", "Interrupt his Soul Drain (it drains the tank's health)." },
        { "Limpia los worgen del piso de arriba antes.", "Clear the worgen on the floor above first." },
      },
      [2749] = { -- Razorclaw the Butcher
        { "No lo atraigas junto con otras patrullas.", "Don't pull him with other patrols." },
        { "Butcher Drain: hay que curarlo.", "Butcher Drain must be healed through." },
      },
      [2750] = { -- Baron Silverlaine
        { "Veil of Shadow (maldición) baja las curas al objetivo un 75 %: quítala si puedes, si no cura más.", "Veil of Shadow (curse) reduces healing on the target by 75%: decurse it if you can, otherwise heal more." },
      },
      [2751] = { -- Commander Springvale
        { "Limpia la sala antes; viene con un Haunted Servitor y un Wailing Guardsman.", "Clear the room first; he pulls with a Haunted Servitor and a Wailing Guardsman." },
        { "Mata primero al Guardsman (silencio en área) e interrumpe el Holy Light de Springvale.", "Kill the Guardsman first (AOE silence) and interrupt Springvale's Holy Light." },
      },
      [2752] = { -- Odo the Blindwatcher
        { "Viene con 2 Vile Bats con Disarm y Cleave: el tanque las aparta del grupo o se controlan.", "He pulls with two Vile Bats that Disarm and Cleave: the tank turns them away from the group, or CC them." },
      },
      [2753] = { -- Fenrus the Devourer
        { "Toxic Saliva daña más al tanque.", "Toxic Saliva deals extra damage to the tank." },
        { "Al 50 % llama a 4 Voidwalkers que siguen vivos si él muere: el tanque debe tomarlos rápido.", "At 50% he summons four Voidwalkers that stay alive after he dies: the tank must grab them fast." },
      },
      [2754] = { -- Wolf Master Nandos
        { "Atrae aparte los worgs de la sala.", "Pull the worgs in the room separately." },
        { "Llama más worgs (no élite, poca vida): mátalos rápido.", "He summons more worgs (non-elite, low HP): kill them ASAP." },
      },
      [2755] = { -- Archmage Arugal
        { "Usa paredes y esquinas para cortar la línea de visión de su Void Bolt y obligarlo a acercarse.", "Use walls and corners to line of sight his Void Bolt and force him to come to you." },
        { "Shadow Port lo teletransporta y baja la amenaza del tanque: no le quites el aggro.", "Shadow Port teleports him and lowers the tank's threat: don't steal aggro." },
      },
    },
    nombres = { ["Rethilgore"] = 2748, ["Razorclaw the Butcher"] = 2749, ["Baron Silverlaine"] = 2750, ["Commander Springvale"] = 2751, ["Odo the Blindwatcher"] = 2752, ["Fenrus the Devourer"] = 2753, ["Wolf Master Nandos"] = 2754, ["Archmage Arugal"] = 2755 },
  },
  [34] = { -- the-stockade
    url = "https://www.icy-veins.com/wow-forever/the-stockade-guide",
    datos = {
      { "Mazmorra para nivel 24-32, en Stormwind City, en un edificio al norte de Mage Quarter.", "Level 24-32 dungeon in Stormwind City, inside a building north of the Mage Quarter." },
      { "Tiene 6 misiones; en la práctica es solo de Alliance: no se recomienda con Horde.", "It has 6 quests; effectively Alliance-only: not recommended for Horde." },
      { "Casi todos los jefes vienen con Defias: controla o mata primero a los acompañantes.", "Most bosses come with Defias mobs: CC or kill the adds first." },
    },
    jefes = {
      [2756] = { -- Targorr the Dread
        { "Mata primero a sus acompañantes.", "Kill his adds before the boss." },
        { "Pega rápido con dos armas (Thrash) y se enfurece al 30 %: sanador, atento al tanque.", "He hits fast with dual-wield (Thrash) and enrages at 30%: healer, watch the tank." },
      },
      [2757] = { -- Kam Deepfury
        { "Controla o mata primero a sus acompañantes.", "CC or kill his adds first." },
        { "Defensive Stance y Shield Slam: cuidado con el aturdimiento de Shield Slam.", "Defensive Stance and Shield Slam: watch out for the Shield Slam stun." },
      },
      [2758] = { -- Hamhock
        { "Chain Lightning: sepárense para que no salte entre jugadores.", "Chain Lightning: stay spread so it doesn't chain." },
      },
      [2760] = { -- Bazil Thredd
        { "Es de nivel algo más alto que el resto.", "He is slightly higher level than the rest." },
        { "Smoke Bomb aturde 4 s a los de cerca y pega rápido con dos armas: el tanque, con la vida llena antes.", "Smoke Bomb stuns nearby players for 4 s and he dual-wields fast: keep the tank topped off." },
      },
      [2759] = { -- Dextren Ward
        { "Limpia todas las salas de alrededor antes: Intimidating Shout es miedo en área.", "Clear all surrounding rooms first: Intimidating Shout is an AOE fear." },
      },
    },
    nombres = { ["Targorr the Dread"] = 2756, ["Kam Deepfury"] = 2757, ["Hamhock"] = 2758, ["Bazil Thredd"] = 2760, ["Dextren Ward"] = 2759 },
  },
  [36] = { -- deadmines
    url = "https://www.icy-veins.com/wow-forever/deadmines-guide",
    datos = {
      { "Mazmorra para nivel 17-26, en Westfall: dentro de una casa de Moonbrook, al sur.", "Level 17-26 dungeon in Westfall, inside a house in Moonbrook to the south." },
      { "Tiene 7 misiones y todas son solo de Alliance: no se recomienda hacerla con Horde.", "It has 7 quests, all Alliance-only: running it as Horde is NOT recommended." },
      { "Para Horde queda lejos: barco desde Ratchet (The Barrens).", "Far for Horde: boat from Ratchet in The Barrens." },
    },
    jefes = {
      [2741] = { -- Rhahk'Zor
        { "Atrae aparte a los 2 Defias Watchmen (ataque a distancia y escóndete en el pasillo).", "Pull the two Defias Watchmen separately (ranged attack and LOS them in the corridor)." },
        { "Aturde a su objetivo: el sanador, listo para curar más.", "He stuns his main target: healer, be ready to heal more." },
      },
      [3676] = { -- Miner Johnson
        { "Raro: no siempre sale. Está rodeado de Defias Miners normales, fáciles de matar.", "Rare spawn: not always there. He is surrounded by normal Defias Miners, easy to kill." },
      },
      [2742] = { -- Sneed
        { "El Shredder tiene miedo en área: limpia los goblins de la sala antes.", "The Shredder has an AOE fear: clear the goblins in the room first." },
        { "Al romper el Shredder sale Sneed; su Disarm le quita amenaza al tanque.", "When the Shredder dies Sneed jumps out; his Disarm costs the tank threat." },
      },
      [2743] = { -- Gilnid
        { "Viene con un Goblin Engineer: contrólalo o mátalo primero (sus robots mueren con él).", "He pulls with a Goblin Engineer: CC or kill it first (its robots die with it)." },
        { "Su efecto de fuego le dificulta la amenaza al tanque.", "His fire debuff makes threat harder for the tank." },
      },
      [2745] = { -- Mr. Smite
        { "Viene con 2 Defias Blackguards: mátalos cuanto antes.", "He pulls with two Defias Blackguards: kill them ASAP." },
        { "Aturde a todo el grupo al 66 % y 33 %; tras el 33 %, Smite Slam pega fuerte al tanque.", "He stuns the whole group at 66% and 33%; after 33%, Smite Slam hits the tank hard." },
      },
      [2744] = { -- Captain Greenskin
        { "Patrulla con un Defias Pirate y un Defias Squallshaper: mata primero al Squallshaper (Frost Nova).", "He patrols with a Defias Pirate and a Defias Squallshaper: kill the Squallshaper first (Frost Nova)." },
        { "Tiene Cleave: los de cuerpo a cuerpo, siempre detrás.", "He has a Cleave: melee, always stay behind him." },
      },
      [2747] = { -- Edwin VanCleef
        { "Al atraerlo salen 2 Defias Blackguard ocultos: mátalos primero.", "Pulling him also pulls two hidden Defias Blackguards: kill them first." },
        { "Al 50 % llama a 2 Blackguards más; con Thrash castiga al tanque.", "At 50% he summons two more Blackguards; with Thrash he chunks the tank." },
      },
      [2746] = { -- Cookie
        { "Aléjalo del barco e interrumpe Cookie's Cooking (lo cura).", "Kite him away from the ship and interrupt Cookie's Cooking (it heals him)." },
      },
    },
    nombres = { ["Rhahk'Zor"] = 2741, ["Miner Johnson"] = 3676, ["Sneed"] = 2742, ["Gilnid"] = 2743, ["Mr. Smite"] = 2745, ["Captain Greenskin"] = 2744, ["Edwin VanCleef"] = 2747, ["Cookie"] = 2746 },
  },
  [43] = { -- wailing-caverns
    url = "https://www.icy-veins.com/wow-forever/wailing-caverns-guide",
    datos = {
      { "Mazmorra para nivel 15-24, en The Barrens, junto a Lushwater Oasis (al suroeste de Crossroads).", "Level 15-24 dungeon in The Barrens, by Lushwater Oasis (southwest of the Crossroads)." },
      { "Para Alliance queda lejos: en barco desde Booty Bay o bajando desde Ashenvale.", "Far for Alliance: by boat from Booty Bay or coming south from Ashenvale." },
      { "Tiene 7 misiones; 2 son solo de Horde.", "It has 7 quests; 2 of them are Horde-only." },
      { "Mutanus the Devourer sale al final tras matar a los 4 líderes y escoltar al Disciple of Naralex desde la entrada.", "Mutanus the Devourer appears at the end after killing the four leaders and escorting the Disciple of Naralex from the entrance." },
    },
    jefes = {
      [585] = { -- Lady Anacondra
        { "Interrumpe su Healing Touch; también lanza Lightning Bolt y Sleep.", "Interrupt her Healing Touch; she also casts Lightning Bolt and Sleep." },
        { "Si atraes una patrulla, contrólala y mata primero a Anacondra.", "If you pull a patrol, CC it and kill Anacondra first." },
      },
      [587] = { -- Kresh
        { "Sin habilidades de cuidado; tiene mucha armadura: usa Sunder Armor o similares.", "No notable abilities; he has high armor: use Sunder Armor or similar." },
      },
      [586] = { -- Lord Cobrahn
        { "Viene con 3 Deviate Pythons (no élite): caen rápido con daño en área.", "He pulls with three Deviate Pythons (non-elite): they die fast to cleave damage." },
        { "Se convierte en serpiente y pega más fuerte y rápido: sanador, atento al tanque.", "He turns into a serpent and hits harder and faster: healers, watch the tank." },
      },
      [588] = { -- Lord Pythas
        { "Suele venir con 1-2 enemigos de más: contrólalos.", "He often comes with 1-2 extra mobs: CC them." },
        { "Interrumpe su Sleep; si no eres de cuerpo a cuerpo, aléjate de su Thunderclap.", "Interrupt his Sleep; if you are not melee, stay away from his Thunderclap." },
      },
      [589] = { -- Skum
        { "Chained Bolt salta entre jugadores juntos: sepárense.", "Chained Bolt jumps between players who are close: stay spread." },
      },
      [590] = { -- Lord Serpentis
        { "Solo tiene Sleep, Lightning Bolt y Healing Touch: interrúmpelo y es fácil.", "He only has Sleep, Lightning Bolt and Healing Touch: keep him interrupted and it's easy." },
      },
      [591] = { -- Verdan the Everliving
        { "Grasping Vines inmoviliza y empuja a todos a 10 yardas: quédate a distancia si puedes.", "Grasping Vines roots and knocks back everyone within 10 yards: stay at range if you can." },
      },
      [592] = { -- Mutanus the Devourer
        { "Durante la escolta, que nada ataque al Disciple; Mutanus llega en la 3.ª oleada.", "During the escort, keep mobs off the Disciple; Mutanus arrives on the third wave." },
        { "Terrify (miedo en área) y Naralex's Nightmare (sueño); Thundercrack daña alrededor: aléjate si no eres de cuerpo a cuerpo.", "Terrify (AOE fear) and Naralex's Nightmare (sleep); Thundercrack hits around him: stay away unless you are melee." },
      },
    },
    nombres = { ["Lady Anacondra"] = 585, ["Kresh"] = 587, ["Lord Cobrahn"] = 586, ["Lord Pythas"] = 588, ["Skum"] = 589, ["Lord Serpentis"] = 590, ["Verdan the Everliving"] = 591, ["Mutanus the Devourer"] = 592 },
  },
  [48] = { -- blackfathom-deeps
    url = "https://www.icy-veins.com/wow-forever/blackfathom-deeps-guide",
    datos = {
      { "Mazmorra para nivel 24-32, en Ashenvale, al norte de Zoram Strand (bajo tierra).", "Level 24-32 dungeon in Ashenvale, north of Zoram Strand (underground)." },
      { "Tiene 13 misiones: 6 solo de Alliance y 6 solo de Horde.", "It has 13 quests: 6 Alliance-only and 6 Horde-only." },
      { "Tras Kelris, enciende los 4 braseros de uno en uno para abrir la puerta: cada uno llama una oleada.", "After Kelris, light the four braziers one at a time to open the door: each one summons a wave." },
    },
    jefes = {
      [2916] = { -- Ghamoo-ra
        { "Trample daña en área: si no hace falta, aléjate del cuerpo a cuerpo.", "Trample deals AOE damage: stay out of melee unless you need to be there." },
        { "Mucha armadura: Sunder Armor y similares ayudan.", "High armor: Sunder Armor and similar help." },
      },
      [2915] = { -- Lady Sarevess
        { "Viene con 2 patrullas naga: contrólalas y mátalas primero.", "She pulls with two naga patrols: CC and kill them first." },
        { "Quita el Frost Nova del tanque; no te juntes con otros (Forked Lightning).", "Dispel Frost Nova from the tank; don't stack with others (Forked Lightning)." },
      },
      [2914] = { -- Geilhast
        { "Los murlocs de su sala huyen con poca vida: llévalos hacia atrás para no atraer más.", "The murlocs in his room flee at low health: pull them back to avoid chain pulls." },
        { "Su Net inmoviliza al tanque (se quita con Blessing of Freedom y similares).", "His Net roots the tank (remove it with Blessing of Freedom or similar)." },
      },
      [2913] = { -- Lorgus Jett
        { "No atraigas naga ni satyrs de más con él.", "Don't pull extra naga or satyrs with him." },
        { "Lightning Shield daña a los de cuerpo a cuerpo: quítalo con Purge o similares.", "Lightning Shield damages melee: remove it with Purge or similar." },
      },
      [2912] = { -- Old Serra'kis
        { "Está bajo el agua: con Unending Breath o Water Breathing Potions es muy fácil.", "He is underwater: with Unending Breath or Water Breathing Potions it's very easy." },
      },
      [2911] = { -- Twilight Lord Kelris
        { "Usa la pared de la entrada del santuario para atraer primero a sus Twilight's Hammer.", "Use the wall at the sanctum's entrance to LOS-pull his Twilight's Hammer mobs first." },
        { "Interrumpe su Mind Blast; Sleep duerme 7 s a los de cerca: el tanque, listo para recuperarlo.", "Interrupt his Mind Blast; Sleep puts nearby players to sleep for 7 s: tank, be ready to taunt him back." },
      },
      [2910] = { -- Aku'mai
        { "Frenzied Rage castiga al tanque: vigila su vida y ayuda a curar.", "Frenzied Rage hits the tank hard: watch its health and off-heal." },
        { "Esquiva las Poison Clouds.", "Dodge the Poison Clouds." },
      },
    },
    nombres = { ["Ghamoo-ra"] = 2916, ["Lady Sarevess"] = 2915, ["Geilhast"] = 2914, ["Lorgus Jett"] = 2913, ["Old Serra'kis"] = 2912, ["Twilight Lord Kelris"] = 2911, ["Aku'mai"] = 2910, ["Gelihast"] = 2914 },
  },
  [389] = { -- ragefire-chasm
    url = "https://www.icy-veins.com/wow-forever/ragefire-chasm-guide",
    datos = {
      { "Mazmorra para nivel 13-18, en Orgrimmar: el nivel más bajo de Cleft of Shadow.", "Level 13-18 dungeon in Orgrimmar, on the lowest level of the Cleft of Shadow." },
      { "Tiene 5 misiones y todas son solo de Horde: no se recomienda hacerla con Alliance.", "It has 5 quests, all Horde-only: running it as Alliance is NOT recommended." },
    },
    jefes = {
      [2732] = { -- Oggleflint
        { "Solo tiene Cleave: cuidado los de cuerpo a cuerpo.", "He only has a Cleave: melee, be careful." },
        { "El peligro es atraer troggs de más junto con él.", "The real danger is pulling extra troggs with him." },
      },
      [2733] = { -- Taragaman the Hungerer
        { "Su derribo puede tirar al tanque a la lava: no lo tanquees cerca de un borde.", "His knockback can toss the tank into the lava: do not tank him near an edge." },
        { "Fire Nova daña a todos a su alrededor: si puedes, quédate fuera de su alcance cuerpo a cuerpo.", "Fire Nova hits everyone around him: stay out of his melee range if you can." },
      },
      [2734] = { -- Jergosh the Invoker
        { "Siempre vienen 2 patrullas con él: contrólalas (por ejemplo Polymorph).", "Two patrols always pull with him: crowd-control them (e.g. Polymorph)." },
        { "Immolate y Curse of Weakness se pueden disipar.", "Immolate and Curse of Weakness can be dispelled." },
      },
      [2735] = { -- Bazzalan
        { "Está subiendo la rampa, en la sala de Jergosh, con 2 acompañantes.", "He is up the ramp in Jergosh's room, with two adds." },
        { "Deadly Poison y Sinister Strike castigan al tanque: controla a los 2 acompañantes y mata primero a Bazzalan.", "Deadly Poison and Sinister Strike hurt the tank: CC both adds and kill Bazzalan first." },
      },
    },
    nombres = { ["Oggleflint"] = 2732, ["Taragaman the Hungerer"] = 2733, ["Jergosh the Invoker"] = 2734, ["Bazzalan"] = 2735 },
  },
  [2998] = { -- excavation-site-wetlands
    url = "https://www.icy-veins.com/wow-forever/excavation-site-wetlands-guide",
    datos = {
      { "Mazmorra para nivel 26-33, en Wetlands, por un camino que empieza al sur de la cueva Thelgen Rock.", "Level 26-33 dungeon in Wetlands, on a path starting just south of the Thelgen Rock cavern." },
      { "Tiene 8 misiones: 5 solo de Alliance y 3 solo de Horde.", "It has 8 quests: 5 Alliance-only and 3 Horde-only." },
    },
    jefes = {
      [3480] = { -- Saltspine
        { "Dust Storm baja el acierto un 25 % cerca de él: aléjate si no hace falta estar ahí.", "Dust Storm lowers hit chance by 25% near him: move out if you don't need to be there." },
        { "Tendon Rip ralentiza al tanque.", "Tendon Rip slows the tank." },
      },
      [3481] = { -- Shadetooth
        { "Limpia los raptores ocultos entre los arbustos; viene con 2 Thicket Hunters (Infected Wound): mátalos primero.", "Clear the stealthed raptors in the bushes; he pulls with two Thicket Hunters (Infected Wound): kill them first." },
        { "Miedo en área, Rend al tanque y Enrage al 30 %: guarda aturdimientos para entonces.", "AOE Fear, Rend on the tank and Enrage at 30%: save stuns for it." },
      },
      [3482] = { -- Relic Guardian
        { "Empieza al usar el Archival Panel de su derecha.", "Start the fight by using the Archival Panel to his right." },
        { "Derribos y aturdimientos al tanque; Thunderclap ralentiza cerca de él: aléjate. Le afecta casi todo el control.", "Knockbacks and stuns on the tank; Thunderclap slows near him: stay away. Most CC works on him." },
      },
    },
    nombres = { ["Saltspine"] = 3480, ["Shadetooth"] = 3481, ["Relic Guardian"] = 3482 },
  },
  [2999] = { -- ruins-of-lordaeron
    url = "https://www.icy-veins.com/wow-forever/ruins-of-lordaeron-guide",
    datos = {
      { "Mazmorra nueva de WoW Forever para nivel 15-20, en Undercity, a la izquierda de la entrada a Ruins of Lordaeron.", "New WoW Forever dungeon for level 15-20, in Undercity, just left of the entrance to the Ruins of Lordaeron." },
      { "Tiene 10 misiones: 6 solo de Horde y 4 solo de Alliance.", "It has 10 quests: 6 Horde-only and 4 Alliance-only." },
      { "Viktor the Vile y The Abandoned son jefes de evento: salen tras varias oleadas.", "Viktor the Vile and The Abandoned are event bosses: they appear after several waves." },
    },
    jefes = {
      [3353] = { -- Witherfang
        { "Patrulla cerca de la entrada (King's Alley) con Broodlings: que no te sorprenda.", "She patrols near the entrance (King's Alley) with Broodlings: don't get jumped." },
        { "Solo envenena al tanque.", "All she does is poison the tank." },
      },
      [3411] = { -- Viktor the Vile
        { "Para llamarlo, usa el Grim Campfire de la chimenea de la casa en ruinas (suroeste).", "To summon him, use the Grim Campfire in the fireplace of the ruined house (southwest)." },
        { "Lo difícil son las oleadas de esqueletos; ayuda al sanador con pociones y curas propias.", "The hard part is the skeleton waves; help your healer with potions and self-healing." },
      },
      [3357] = { -- The Abandoned
        { "Sale tras 3 oleadas al acercarte a la estatua de ojos rojos (oeste).", "He spawns after three waves when you walk near the red-eyed statue (west)." },
        { "Interrumpe o aturde su Drain Life; Frost Nova inmoviliza y Frost Armor ralentiza a quien lo golpea.", "Interrupt or stun his Drain Life; Frost Nova roots and Frost Armor slows those who attack him." },
      },
      [3412] = { -- Bjork
        { "Combate sencillo: solo tiene un derribo; no te dejes empujar contra otros enemigos.", "Simple fight: only a knockback; don't get knocked into other mobs." },
      },
      [3354] = { -- Rath'mael
        { "Mata a los enemigos de su zona para empezar el combate.", "Kill the mobs around him to engage the boss." },
        { "Interrumpe o aturde su Flamestrike; su daño en área a los de cuerpo a cuerpo hay que curarlo.", "Interrupt or stun his Flamestrike; his AOE around him hurts melee and must be healed through." },
      },
      [3408] = { -- Lordaeron Captain
        { "Raro: puede salir al oeste cuando los demás jefes están muertos. Es amistoso con Alliance: solo lo mata Horde.", "Rare: may spawn in the west once all other bosses are dead. Friendly to Alliance: only Horde can kill him." },
        { "Cuidado con su patrulla larga y los enemigos de su zona.", "Watch out for his long patrol and the many mobs around him." },
      },
    },
    nombres = { ["Witherfang"] = 3353, ["Viktor the Vile"] = 3411, ["The Abandoned"] = 3357, ["Bjork"] = 3412, ["Rath'mael"] = 3354, ["Lordaeron Captain"] = 3408 },
  },
  [3065] = { -- hall-of-thanes
    url = "https://www.icy-veins.com/wow-forever/hall-of-thanes-guide",
    datos = {
      { "Mazmorra nueva de WoW Forever para nivel 13-18, en Ironforge, bajo el Throne Room (zona de Old Ironforge).", "New WoW Forever dungeon for level 13-18, in Ironforge, under the Throne Room (Old Ironforge)." },
      { "Entrada: en el Throne Room baja por el pasillo de la izquierda hasta el fondo de Old Ironforge.", "Entrance: in the Throne Room take the left corridor down to the bottom of Old Ironforge." },
      { "Tiene 5 misiones; 3 son solo de Alliance.", "It has 5 quests; 3 of them are Alliance-only." },
    },
    jefes = {
      [3493] = { -- Faldrim Anvilmar
        { "Limpia algunos Enraged Apparition de la sala antes de atraerlo.", "Clear a few Enraged Apparitions in the room before pulling him." },
        { "Interrumpe su Mind Blast; Anvilmar's Curse baja la velocidad de ataque del tanque.", "Interrupt his Mind Blast; Anvilmar's Curse lowers the tank's attack speed." },
      },
      [3494] = { -- Plunder
        { "Su derribo puede mandarte contra otros enemigos: el tanque debe colocarlo bien.", "His knockback can send you into other mobs: the tank must position him carefully." },
        { "Lo fácil: llevarlo a la sala anterior.", "Easy way: bring him back to the previous room." },
      },
      [3496] = { -- Durgen Dirgehammer
        { "Limpia los Dark Iron de alrededor antes de atraerlo.", "Clear the Dark Iron mobs around the room before pulling him." },
        { "Mata primero a los 2 Lesser Stone Golems: tiene miedo en área y Rend.", "Kill the two Lesser Stone Golems first: he has an AOE Fear and Rend." },
      },
    },
    nombres = { ["Faldrim Anvilmar"] = 3493, ["Plunder"] = 3494, ["Durgen Dirgehammer"] = 3496 },
  },
}
