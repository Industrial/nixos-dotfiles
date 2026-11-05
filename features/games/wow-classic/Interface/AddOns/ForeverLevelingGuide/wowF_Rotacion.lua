-- Forever Leveling Guide: pestanas Rotacion y Macros del Libro (wowF_Libro.lua las dibuja con WowF.contenidoRotacion/Macros).
-- Rotacion: prioridad de golpes de tu rama para subir de nivel. Marca lo que ya tienes (IsPlayerSpell sobre todos los rangos),
-- lo que te falta entrenar, lo que llega a nivel N y los talentos (con el nivel en que tu plan los coge).
-- Macros: las mas usadas de tu clase por nivel. Clic = se crea en tu lista de macros (por personaje); tambien se puede copiar.
-- Los nombres de hechizo de las macros salen del cliente (GetSpellInfo), asi funcionan con el juego en ingles o en espanol.
-- Niveles e ids: WowFHechizos (wowF_Hechizos.lua, generado). Textos: L(espanol, ingles) segun el idioma del addon.

WowF = WowF or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
-- Nombre de cada macro en ingles (el juego admite 16 letras). La clave interna (y lo guardado) sigue siendo el nombre en espanol.
local MACRO_EN = { ["FG Carga"] = "FG Charge", ["FG Juicio"] = "FG Judgement", ["FG Martillo"] = "FG Hammer",
  ["FG Aspectos"] = "FG Aspects", ["FG Mascota"] = "FG Pet", ["FG Fingir"] = "FG Feign", ["FG Abrir"] = "FG Opener",
  ["FG Escudo"] = "FG Shield", ["FG Interrumpir"] = "FG Interrupt", ["FG Remate"] = "FG Finisher", ["FG Varita"] = "FG Wand",
  ["FG Miedo"] = "FG Fear", ["FG Formas"] = "FG Forms", ["FG Cura propia"] = "FG Self Heal", ["FG Gato"] = "FG Cat",
  ["FG Oso"] = "FG Bear", ["FG Prueba"] = "FG Test" }
local function nombreMacro(es) if WowF.enIngles and WowF.enIngles() then return MACRO_EN[es] or es end return es end
-- La macro ya creada, con el nombre de cualquiera de los dos idiomas (se creo antes de cambiar el idioma)
local function indiceMacro(es)
  if not GetMacroIndexByName then return 0 end
  local i = GetMacroIndexByName(es) or 0
  if (not i or i == 0) and MACRO_EN[es] then i = GetMacroIndexByName(MACRO_EN[es]) or 0 end
  return i or 0
end
WowF.nombreMacro = nombreMacro

-- ===================== Rotaciones por clase y rama =====================
-- { "Hechizo", "para que (es)", "why (en)" } en orden de prioridad. La clave es la rama con la que subes ahora.
local ROT = {
  -- Fuentes (4-oct-2026): guias de nivel 20 de Wowhead /forever (primero) y de nivel 30 de Icy Veins /wow-forever.
  -- Solo hechizos que existen en Forever y llegan antes del nivel 31 (tope de la beta: 30). Detalle en historial/project_wowf_guia_app.md.
  WARRIOR = {
    Arms = {
      { "Battle Shout", "Antes de pelear y mantenlo toda la pelea.", "Before the pull, and keep it up all fight." },
      { "Bloodrage", "Ira gratis: mejor entre peleas.", "Free rage: best between pulls." },
      { "Charge", "Para entrar (solo fuera de combate).", "To open (out of combat only)." },
      { "Rend", "Sangrado: mantenlo si el enemigo va a durar.", "Bleed: keep it up if the enemy will last." },
      { "Slam", "Justo despues de tu golpe normal (si estas por golpear, salta al siguiente).", "Right after your auto-attack (if a swing is about to land, skip to the next one)." },
      { "Thunder Clap", "Mantenlo puesto: el enemigo pega mas lento.", "Keep it up: the enemy attacks slower." },
      { "Victory Rush", "Tras matar: golpe gratis que te cura.", "After a kill: free hit that heals you." },
      { "Overpower", "En cuanto se encienda (el enemigo esquivo).", "As soon as it lights up (the enemy dodged)." },
      { "Demoralizing Shout", "Contra enemigos que pegan cuerpo a cuerpo: pegan menos.", "Against melee enemies: they hit softer." },
      { "Sunder Armor", "Una o dos veces al empezar (no si le queda menos de la mitad).", "Once or twice early (not below half health)." },
      { "Heroic Strike", "Solo si te sobra ira.", "Only when you have rage to spare." },
      { "Cleave", "2 o mas enemigos pegados.", "2 or more enemies together." },
      { "Sweeping Strikes", "Con 2 enemigos juntos y ira guardada.", "With 2 enemies together and rage saved up." },
    },
    Fury = {
      { "Battle Shout", "Antes de pelear y mantenlo.", "Before the pull, and keep it up." },
      { "Bloodrage", "Ira gratis: mejor entre peleas.", "Free rage: best between pulls." },
      { "Charge", "Para entrar (solo fuera de combate).", "To open (out of combat only)." },
      { "Rend", "Si el enemigo va a vivir todo el sangrado.", "If the enemy will live through the whole bleed." },
      { "Overpower", "En cuanto se encienda (el enemigo esquivo).", "As soon as it lights up (the enemy dodged)." },
      { "Victory Rush", "Tras matar: golpe gratis que te cura.", "After a kill: free hit that heals you." },
      { "Sunder Armor", "Si al enemigo le queda mas del 70 % de vida.", "If the enemy is above 70% health." },
      { "Heroic Strike", "Para gastar la ira que sobra.", "To spend spare rage." },
      { "Cleave", "En vez de Heroic Strike con 2 o mas enemigos.", "Instead of Heroic Strike with 2+ enemies." },
      { "Demoralizing Shout", "Contra enemigos que pegan cuerpo a cuerpo.", "Against melee enemies." },
    },
    Protection = {
      { "Defensive Stance", "Postura para tanquear (mision de clase a nivel 10).", "Tanking stance (class quest at level 10)." },
      { "Charge", "Para entrar: desde Battle Stance (hasta tener Vanguard a nivel 25).", "To open: from Battle Stance (until Vanguard at level 25)." },
      { "Bloodrage", "Al empezar: ira gratis.", "At the start: free rage." },
      { "Shield Block", "Usalo mucho: menos dano y enciende Revenge.", "Use it a lot: less damage and it lights up Revenge." },
      { "Revenge", "En cuanto se encienda.", "As soon as it lights up." },
      { "Thunder Clap", "Varios enemigos: amenaza y pegan mas lento.", "Several enemies: threat and slower attacks." },
      { "Demoralizing Shout", "Para que te peguen menos (enemigos cuerpo a cuerpo); desde el parche del 8-oct ademas da algo de amenaza a todos los que alcanza.", "So they hit you softer (melee enemies); since the Oct 8 patch it also puts some threat on every target hit." },
      { "Sunder Armor", "En grupo y en jefes: 5 cargas (da poca amenaza en la beta).", "In groups and on bosses: 5 stacks (low threat on the beta)." },
      { "Rend", "Si ya tienes buena amenaza.", "If you already have solid threat." },
      { "Heroic Strike", "Si te sobra ira.", "With spare rage." },
      { "Shield Bash", "Interrumpe hechizos.", "Interrupt casts." },
      { "Battle Shout", "Si eres el unico Warrior del grupo.", "If you are the only Warrior in the group." },
    },
  },
  PALADIN = {
    Retribution = {
      { "Blessing of Might", "Siempre puesto: mas poder de ataque.", "Always on: more attack power." },
      { "Seal of Righteousness", "Tu sello: ponlo y renuevalo cuando se acabe. El mejor con arma rapida o con mucho poder con hechizos.", "Your seal: put it on and renew it when it ends. Best with a fast weapon or lots of spell power." },
      { "Seal of Command", "En vez de Seal of Righteousness solo con un arma lenta sin efectos al golpear.", "Instead of Seal of Righteousness only with a slow weapon without on-hit effects." },
      { "Judgement", "Cada vez que este listo.", "On cooldown." },
      { "Holy Strike", "Cada vez que este listo.", "On cooldown." },
      { "Exorcism", "Cada vez que este listo contra no-muertos y demonios.", "On cooldown against undead and demons." },
      -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L68): Consecration 4,2 % de poder con hechizos por tick (antes 9,5 %)
      { "Consecration", "Solo con varios enemigos (gasta mucho mana; desde el parche del 15-oct hace menos dano).", "Only with several enemies (costs a lot of mana; since the Oct 15 patch it deals less damage)." },
      { "Hammer of Justice", "Aturde a un enemigo peligroso.", "Stun a dangerous enemy." },
    },
    Protection = {
      { "Righteous Fury", "Siempre puesto: mas amenaza.", "Always on: more threat." },
      { "Retribution Aura", "Aura siempre puesta (antes del 16: Devotion Aura).", "Aura always on (before 16: Devotion Aura)." },
      -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L78): Seal of Fury ya no lo quita Power Word: Shield; rango 3 a nivel 26 (antes 25)
      { "Seal of Fury", "Ponlo antes de pelear y mantenlo (rango 3 a nivel 26; Power Word: Shield ya no lo quita).", "Put it on before the pull and keep it up (rank 3 at level 26; Power Word: Shield no longer removes it)." },
      { "Judgement", "Cada vez que este listo.", "On cooldown." },
      { "Exorcism", "Contra no-muertos y demonios.", "Against undead and demons." },
      { "Holy Strike", "Cada vez que este listo.", "On cooldown." },
      { "Consecration", "Con varios enemigos, primero; con uno, si te sobra mana (desde el parche del 15-oct hace menos dano).", "With several enemies, first; with one, if mana allows (since the Oct 15 patch it deals less damage)." },
    },
    Holy = {
      { "Blessing of Might", "A ti y a tu grupo.", "On you and your group." },
      { "Devotion Aura", "Aura siempre puesta (o Retribution Aura).", "Aura always on (or Retribution Aura)." },
      { "Seal of Righteousness", "Para hacer dano: sello siempre.", "To deal damage: keep a seal up." },
      { "Judgement", "Cada vez que este listo.", "On cooldown." },
      { "Holy Strike", "Cada vez que este listo.", "On cooldown." },
      { "Consecration", "Dano en area, pero cuesta mucho mana (desde el parche del 15-oct hace menos dano).", "Area damage, but costs a lot of mana (since the Oct 15 patch it deals less damage)." },
      { "Flash of Light", "Tu cura principal desde el nivel 20.", "Your main heal from level 20." },
      { "Holy Light", "Cura grande y cara: solo si sobra mana o alguien esta en peligro.", "Big, expensive heal: only with spare mana or someone in danger." },
      { "Holy Shock", "Cura instantanea para emergencias.", "Instant heal for emergencies." },
      { "Lay on Hands", "Ultimo recurso: cura mucho y gasta todo tu mana.", "Last resort: big heal that uses all your mana." },
    },
  },
  HUNTER = {
    -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L99): Multi-Shot instantaneo (antes 0,5 s)
    ["Beast Mastery"] = {
      { "Aspect of the Hawk", "Siempre puesto al pelear.", "Always on while fighting." },
      { "Hunter's Mark", "Marca al enemigo antes de pelear.", "Mark the target before the fight." },
      { "Serpent Sting", "Cuando tu mascota ya le pego; renuevalo.", "Once your pet has hit it; refresh it." },
      { "Summon Hawk", "Cada vez que este listo: ten siempre 2 halcones.", "On cooldown: always keep 2 hawks up." },
      { "Aimed Shot", "Cada vez que este listo (un enemigo).", "On cooldown (single target)." },
      { "Multi-Shot", "En vez de Aimed Shot con varios enemigos (instantaneo desde el parche del 15-oct).", "Instead of Aimed Shot with several enemies (instant since the Oct 15 patch)." },
      { "Arcane Shot", "Si te sobra mana.", "If you have spare mana." },
      { "Disengage", "Si le quitas el enemigo a tu mascota.", "If you pull the enemy off your pet." },
      { "Mend Pet", "Si tu mascota baja de vida.", "If your pet gets low." },
    },
    Marksmanship = {
      { "Aspect of the Hawk", "Siempre puesto al pelear.", "Always on while fighting." },
      { "Hunter's Mark", "Marca al enemigo antes de pelear.", "Mark the target before the fight." },
      { "Serpent Sting", "Cuando tu mascota ya le pego.", "Once your pet has hit it." },
      { "Aimed Shot", "Cada vez que este listo (un enemigo).", "On cooldown (single target)." },
      { "Multi-Shot", "En vez de Aimed Shot con varios enemigos (instantaneo desde el parche del 15-oct).", "Instead of Aimed Shot with several enemies (instant since the Oct 15 patch)." },
      { "Arcane Shot", "Cada vez que este listo si te sobra mana.", "On cooldown if you have spare mana." },
      { "Disengage", "Si le quitas el enemigo a tu mascota.", "If you pull the enemy off your pet." },
      { "Mend Pet", "Si tu mascota baja de vida.", "If your pet gets low." },
    },
    Survival = {
      { "Aspect of the Hawk", "Siempre puesto al pelear.", "Always on while fighting." },
      { "Hunter's Mark", "Marca al enemigo antes de pelear.", "Mark the target before the fight." },
      { "Serpent Sting", "Al empezar.", "At the start." },
      { "Raptor Strike", "Cada vez que estes cuerpo a cuerpo: mezcla golpes cerca y disparos.", "Whenever you are in melee: mix melee hits and shots." },
      { "Mongoose Bite", "Cuerpo a cuerpo, cada vez que se encienda (tras esquivar el enemigo).", "In melee, whenever it lights up (after the enemy dodges)." },
      { "Aimed Shot", "A distancia, al empezar la pelea.", "At range, to open the fight." },
      { "Arcane Shot", "A distancia.", "At range." },
      { "Disengage", "Si le quitas el enemigo a tu mascota.", "If you pull the enemy off your pet." },
      { "Mend Pet", "Si tu mascota baja de vida.", "If your pet gets low." },
    },
  },
  ROGUE = {
    Combat = {
      { "Stealth", "Acercate sin que te vean.", "Sneak up unseen." },
      { "Cheap Shot", "Para abrir desde Stealth: aturde y te da ventaja.", "Opener from Stealth: stun and an early edge." },
      { "Slice and Dice", "Mantenlo siempre puesto; renuevalo justo cuando se acaba.", "Keep it up at all times; refresh it right as it ends." },
      { "Sinister Strike", "Tu golpe principal (da puntos de combo).", "Your main builder (gives combo points)." },
      { "Backstab", "En vez de Sinister Strike si llevas daga y estas detras.", "Instead of Sinister Strike with a dagger from behind." },
      { "Eviscerate", "Con 5 puntos si Slice and Dice ya esta puesto.", "At 5 points if Slice and Dice is already up." },
      { "Expose Armor", "En grupo con mucho dano fisico y enemigos que duran.", "In groups with heavy physical damage and long fights." },
      { "Kick", "Interrumpe hechizos.", "Interrupt casts." },
      { "Gouge", "Incapacita al enemigo para recibir menos dano.", "Incapacitate the enemy to take less damage." },
    },
    Assassination = {
      { "Stealth", "Acercate sin que te vean.", "Sneak up unseen." },
      { "Ambush", "Para abrir desde Stealth por la espalda (con daga).", "Opener from Stealth from behind (dagger)." },
      { "Cheap Shot", "Otra forma de abrir: aturde y te da ventaja.", "Another opener: stun and an early edge." },
      { "Mutilate", "Tu golpe principal desde que lo tengas (talento).", "Your main builder once you have it (talent)." },
      { "Backstab", "Golpe principal hasta tener Mutilate, si estas detras.", "Main builder until Mutilate, if you are behind." },
      { "Sinister Strike", "Si no puedes ponerte detras.", "If you can't get behind." },
      { "Slice and Dice", "Con 5 puntos si el enemigo va a durar.", "At 5 points if the enemy will last." },
      { "Eviscerate", "Con 5 puntos si Slice and Dice ya esta puesto.", "At 5 points if Slice and Dice is already up." },
      { "Expose Armor", "En grupo con mucho dano fisico y enemigos que duran.", "In groups with heavy physical damage and long fights." },
      { "Kick", "Interrumpe hechizos.", "Interrupt casts." },
      { "Gouge", "Incapacita al enemigo para recibir menos dano.", "Incapacitate the enemy to take less damage." },
    },
    Subtlety = {
      { "Stealth", "Acercate sin que te vean.", "Sneak up unseen." },
      { "Ambush", "Para abrir desde Stealth por la espalda (con daga).", "Opener from Stealth from behind (dagger)." },
      { "Cheap Shot", "Otra forma de abrir: aturde y te da ventaja.", "Another opener: stun and an early edge." },
      { "Backstab", "Tu golpe principal: daga y por la espalda.", "Your main builder: dagger, from behind." },
      { "Hemorrhage", "Desde el nivel 30 (talento): tu golpe principal siempre; no hace falta estar detras.", "From level 30 (talent): your main builder at all times; no need to be behind." },
      { "Sinister Strike", "Si no puedes ponerte detras.", "If you can't get behind." },
      { "Slice and Dice", "Mantenlo siempre puesto; renuevalo justo cuando se acaba.", "Keep it up at all times; refresh it right as it ends." },
      { "Rupture", "Desde el nivel 30 con esta build: en enemigos que vivan toda su duracion; mejor que Slice and Dice.", "From level 30 with this build: on enemies that live its full duration; better than Slice and Dice." },
      { "Eviscerate", "Con 5 puntos si Slice and Dice ya esta puesto.", "At 5 points if Slice and Dice is already up." },
      { "Expose Armor", "En grupo con mucho dano fisico y enemigos que duran.", "In groups with heavy physical damage and long fights." },
      { "Kick", "Interrumpe hechizos.", "Interrupt casts." },
      { "Gouge", "Incapacita al enemigo para recibir menos dano.", "Incapacitate the enemy to take less damage." },
    },
  },
  PRIEST = {
    Shadow = {
      { "Power Word: Fortitude", "Siempre puesto.", "Always on." },
      { "Inner Fire", "Siempre puesto.", "Always on." },
      { "Power Word: Shield", "Escudo antes de pelear.", "Shield before the pull." },
      { "Holy Fire", "Para abrir (opcional; antes del 20: Smite).", "To open (optional; before 20: Smite)." },
      { "Mind Blast", "Despues de abrir; otra vez si el enemigo aguanta.", "After the opener; again if the enemy lasts." },
      { "Shadow Word: Pain", "Dano con el tiempo; en grupo, en varios si te sobra mana.", "Damage over time; in groups, on several if mana allows." },
      { "Mind Flay", "Talento: despues de Mind Blast y Shadow Word: Pain; vigila el mana.", "Talent: after Mind Blast and Shadow Word: Pain; watch your mana." },
      { "Smite", "Para abrir hasta tener Holy Fire.", "To open until you get Holy Fire." },
      { "Renew", "Si te preocupa tu vida.", "If you worry about your health." },
    },
    Discipline = {
      { "Power Word: Fortitude", "Siempre puesto.", "Always on." },
      { "Inner Fire", "Siempre puesto.", "Always on." },
      { "Power Word: Shield", "Antes de pelear; en grupo, al tanque.", "Before the pull; in groups, on the tank." },
      { "Holy Fire", "Para abrir (antes del 20: Smite).", "To open (before 20: Smite)." },
      { "Mind Blast", "Despues de abrir.", "After the opener." },
      { "Shadow Word: Pain", "Dano con el tiempo.", "Damage over time." },
      { "Smite", "Para abrir hasta tener Holy Fire.", "To open until you get Holy Fire." },
      { "Renew", "Al tanque, o a ti si te preocupa tu vida.", "On the tank, or on you if you worry about your health." },
      { "Heal", "Tu cura principal en grupo.", "Your main heal in groups." },
      { "Flash Heal", "Solo si alguien esta por morir (gasta mucho mana).", "Only if someone is about to die (costs a lot of mana)." },
      { "Prayer of Healing", "Si todo el grupo esta muy herido.", "When the whole group is badly hurt." },
    },
    Holy = {
      { "Power Word: Fortitude", "Siempre puesto.", "Always on." },
      { "Inner Fire", "Siempre puesto.", "Always on." },
      { "Power Word: Shield", "Antes de pelear; en grupo, al tanque.", "Before the pull; in groups, on the tank." },
      { "Holy Fire", "Para abrir (antes del 20: Smite).", "To open (before 20: Smite)." },
      { "Mind Blast", "Despues de abrir.", "After the opener." },
      { "Shadow Word: Pain", "Dano con el tiempo.", "Damage over time." },
      { "Smite", "Para abrir hasta tener Holy Fire.", "To open until you get Holy Fire." },
      { "Renew", "Mantenlo en el tanque.", "Keep it on the tank." },
      { "Heal", "Tu cura principal en grupo.", "Your main heal in groups." },
      { "Flash Heal", "Solo si alguien esta por morir.", "Only if someone is about to die." },
    },
  },
  SHAMAN = {
    Enhancement = {
      { "Lightning Shield", "Ponlo entre peleas.", "Put it up between pulls." },
      { "Lightning Bolt", "Para atraer al enemigo; luego ahorra mana y pega con el arma.", "To pull; then save mana and use your weapon." },
      { "Stormstrike", "Cada vez que este listo (talento); despues gasta su efecto con Earth Shock.", "On cooldown (talent); then consume its effect with Earth Shock." },
      { "Earth Shock", "Para atraer o rematar; con Stormstrike, cada vez que este listo.", "To pull or finish; with Stormstrike, on cooldown." },
      { "Flame Shock", "Para atraer o rematar; en grupo, alternalo con Earth Shock.", "To pull or finish; in a group, alternate it with Earth Shock." },
      { "Searing Totem", "Con varios enemigos o en mazmorras.", "With several enemies or in dungeons." },
      { "Fire Nova", "Varios enemigos: cada vez que este listo, con un totem de fuego puesto y mientras tengas mana.", "Several enemies: on cooldown, with a fire totem down and while mana lasts." },
    },
    Elemental = {
      { "Strength of Earth Totem", "Totems antes de pelear.", "Totems before the pull." },
      { "Call of the Elements", "Pone tus totems a la vez (nivel 20).", "Drops your totems at once (level 20)." },
      { "Lightning Bolt", "Para atraer y como relleno.", "To pull and as filler." },
      { "Flame Shock", "Justo despues; renuevalo en enemigos que duran.", "Right after; refresh it on long-lived enemies." },
      { "Earth Shock", "Alternalo con Flame Shock si no quieres lanzar.", "Alternate with Flame Shock if you don't want to hard-cast." },
      { "Searing Totem", "El ultimo totem, justo antes de atraer.", "Last totem, right before pulling." },
      { "Fire Nova", "Con 3 o mas enemigos, cada vez que este listo.", "With 3+ enemies, on cooldown." },
    },
    Restoration = {
      { "Strength of Earth Totem", "Totems de apoyo para tu grupo.", "Support totems for your group." },
      { "Call of the Elements", "Si pones 2 o mas totems a la vez.", "If you drop 2+ totems at once." },
      { "Healing Wave", "A quien este muy herido, sobre todo al tanque.", "On anyone badly hurt, above all the tank." },
      { "Searing Totem", "Varios enemigos, si no entra mucho dano.", "Several enemies, if damage taken is low." },
      { "Fire Nova", "Varios enemigos, mientras tengas mana.", "Several enemies, while mana lasts." },
    },
  },
  MAGE = {
    Frost = {
      { "Arcane Intellect", "Siempre puesto.", "Always on." },
      { "Frost Armor", "Armadura siempre puesta.", "Armor always on." },
      { "Frostbolt", "Tu golpe principal hasta que al enemigo le quede poco.", "Your main spell until the enemy is almost dead." },
      { "Frost Nova", "Usalo mucho si te pegan: congelalo y alejate.", "Use it often when hit: freeze and back off." },
      { "Ice Lance", "Mientras el enemigo esta congelado o cuando se encienda Fingers of Frost (talento, nivel 30); comparte 8 s de reutilizacion con Fire Blast.", "While the enemy is frozen or when Fingers of Frost procs (talent, level 30); shares an 8 sec cooldown with Fire Blast." },
      { "Fire Blast", "Para rematar.", "To finish." },
      { "Blizzard", "3 o mas enemigos.", "3+ enemies." },
      { "Arcane Explosion", "3 o mas enemigos si no duran todo Blizzard o te tienes que mover.", "3+ enemies if they won't last a full Blizzard or you must move." },
    },
    Fire = {
      { "Arcane Intellect", "Siempre puesto.", "Always on." },
      { "Frost Armor", "Armadura siempre puesta.", "Armor always on." },
      { "Pyroblast", "Para abrir.", "To open." },
      { "Fireball", "Relleno.", "Filler." },
      { "Fire Blast", "Mientras te mueves o para rematar.", "While moving or to finish." },
      { "Frost Nova", "Si se te acerca: congelalo y alejate.", "If it gets close: freeze and back off." },
      { "Flamestrike", "Varios enemigos: lanzalo primero.", "Several enemies: cast it first." },
      { "Blast Wave", "Talento del 30: varios enemigos despues de Flamestrike, o si necesitas frenarlos.", "Level 30 talent: several enemies after Flamestrike, or when you need to slow them." },
      { "Arcane Explosion", "Varios enemigos cerca.", "Several enemies close." },
    },
    Arcane = {
      { "Arcane Intellect", "Siempre puesto.", "Always on." },
      { "Frost Armor", "Armadura siempre puesta.", "Armor always on." },
      -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L189/207/209): Frost Blast nuevo al 24 (reemplaza el uso de Frostbolt rango 1); Arcane Blast redisenado: 1,5 s, cada carga suma 15 % del Intelecto como poder con hechizos y sube el costo, hasta 4, 15 s; Missile Barrage ya no abarata el 2.o Arcane Missiles
      { "Frostbolt", "Para atraer: el enemigo llega frenado.", "To pull: the enemy arrives slowed." },
      { "Arcane Blast", "Hasta 2-4 cargas: cada una suma poder con hechizos y sube el costo (dura 18 s desde la primera); luego Arcane Missiles.", "Up to 2-4 stacks: each adds spell power and raises the cost (lasts 18 s from the first); then Arcane Missiles." },
      { "Arcane Missiles", "Despues de Arcane Blast, o cuando se encienda Missile Barrage.", "After Arcane Blast, or when Missile Barrage lights up." },
      { "Fire Blast", "Mientras te mueves o para rematar.", "While moving or to finish." },
      { "Frost Nova", "Para alejarte de varios enemigos.", "To get away from several enemies." },
      { "Flamestrike", "Varios enemigos juntos.", "Several enemies together." },
      { "Cone of Cold", "Para frenar a varios enemigos.", "To slow several enemies." },
      { "Arcane Explosion", "Varios enemigos cerca.", "Several enemies close." },
    },
  },
  WARLOCK = {
    Affliction = {
      { "Summon Succubus", "Manda primero a tu demonio (antes del 20: Imp o Voidwalker).", "Send your demon in first (before 20: Imp or Voidwalker)." },
      { "Bane of Agony", "El primer dano con el tiempo: da poca amenaza.", "First damage over time: low threat." },
      { "Corruption", "Despues de Bane of Agony.", "After Bane of Agony." },
      { "Immolate", "Despues de Corruption.", "After Corruption." },
      { "Siphon Life", "Si el enemigo va a durar 20 segundos o mas.", "If the enemy will last 20 seconds or more." },
      { "Shadow Bolt", "Cuando sale instantaneo (Nightfall).", "When it turns instant (Nightfall)." },
      { "Drain Life", "Si necesitas vida.", "When you need health." },
      { "Drain Soul", "Para rematar si te faltan fragmentos.", "To finish if you need shards." },
      { "Life Tap", "Cambia vida por mana si vas bien de vida.", "Trade health for mana when your health is safe." },
    },
    Destruction = {
      { "Summon Succubus", "Manda primero a tu demonio (antes del 20: Imp o Voidwalker).", "Send your demon in first (before 20: Imp or Voidwalker)." },
      { "Bane of Agony", "Dano con el tiempo.", "Damage over time." },
      { "Corruption", "Dano con el tiempo.", "Damage over time." },
      { "Immolate", "Tu dano con el tiempo principal.", "Your main damage over time." },
      { "Shadow Bolt", "Relleno.", "Filler." },
      { "Conflagrate", "Al final de Immolate o para rematar (gasta Immolate).", "Near the end of Immolate or to finish (consumes Immolate)." },
      { "Shadowburn", "Para rematar (recuperas el fragmento).", "To finish (you get the shard back)." },
      { "Searing Pain", "Si necesitas un hechizo mas rapido (da mucha amenaza).", "When you need a faster cast (high threat)." },
      { "Drain Soul", "Para rematar si te faltan fragmentos.", "To finish if you need shards." },
      { "Life Tap", "Cambia vida por mana si vas bien de vida.", "Trade health for mana when your health is safe." },
    },
    Demonology = {
      { "Summon Succubus", "Manda primero a tu demonio (antes del 20: Imp o Voidwalker).", "Send your demon in first (before 20: Imp or Voidwalker)." },
      { "Bane of Agony", "El primer dano con el tiempo: da poca amenaza.", "First damage over time: low threat." },
      { "Corruption", "Despues de Bane of Agony.", "After Bane of Agony." },
      { "Immolate", "Despues de Corruption; luego, varita.", "After Corruption; then, wand." },
      { "Life Tap", "Cambia vida por mana si vas bien de vida.", "Trade health for mana when your health is safe." },
    },
  },
  DRUID = {
    ["Feral Combat (Cat)"] = {
      { "Cat Form", "Pelea en forma de gato (mision de clase a nivel 20).", "Fight in Cat Form (class quest at level 20)." },
      { "Rip", "Con 4-5 puntos si el enemigo va a durar 6 segundos o mas.", "At 4-5 points if the enemy will last 6+ seconds." },
      { "Shifting Power", "Cada vez que este listo, con menos de 60 de energia (con la energia llena no se puede).", "On cooldown, with less than 60 Energy (it can't be used at full Energy)." },
      { "Shred", "Tu golpe principal si estas detras del enemigo; usalo cuando salte Clearcasting.", "Your main builder when you are behind the enemy; use it on Clearcasting." },
      { "Claw", "Tu golpe principal si no puedes ponerte detras del enemigo.", "Your main builder when you can't get behind the enemy." },
      { "Bear Form", "Antes del 20: pelea en forma de oso.", "Before 20: fight in Bear Form." },
      { "Maul", "Antes del 20, en Bear Form: tu golpe principal.", "Before 20, in Bear Form: your main attack." },
    },
    ["Feral Combat (Bear)"] = {
      { "Wrath", "Para atraer desde lejos, antes de entrar en Bear Form.", "To pull from range, before entering Bear Form." },
      { "Bear Form", "Pelea en forma de oso (mision de clase a nivel 10).", "Fight in Bear Form (class quest at level 10)." },
      { "Demoralizing Roar", "Mantenlo en los enemigos que tanqueas; desde el parche del 8-oct ademas da algo de amenaza a todos los que alcanza.", "Keep it on the enemies you tank; since the Oct 8 patch it also puts some threat on every target hit." },
      { "Enrage", "Al empezar: te da ira (baja un poco tu armadura).", "At the start: gives you Rage (lowers your armor a bit)." },
      { "Primal Bite", "Tu gasto principal de ira; usalo cuando salte Clearcasting.", "Your main Rage spender; use it on Clearcasting." },
      { "Maul", "Con un enemigo, para gastar la ira que sobra.", "Single target, to spend extra Rage." },
      { "Swipe", "Varios enemigos.", "Several enemies." },
      { "Moonfire", "Antes del nivel 10: mantenlo y lanza Wrath mientras llega.", "Before level 10: keep it up and cast Wrath while it comes." },
    },
    Balance = {
      { "Wrath", "Para abrir desde la distancia maxima y como relleno hasta que muera.", "To open from max range and as filler until it dies." },
      { "Moonfire", "Despues de abrir: mantenlo en cada enemigo.", "After the opener: keep it on every enemy." },
      { "Insect Swarm", "Despues de Moonfire (talento, nivel 25).", "After Moonfire (talent, level 25)." },
      { "Entangling Roots", "Para que no llegue a ti; repitelo si se suelta.", "To keep it away from you; recast if it breaks free." },
      { "Rejuvenation", "Sobre ti cuando haga falta o entre peleas.", "On yourself when needed or between pulls." },
    },
    Restoration = {
      { "Thorns", "En el tanque: ayuda con la amenaza.", "On the tank: helps with threat." },
      { "Rejuvenation", "En el tanque mientras pelea.", "On the tank while fighting." },
      { "Regrowth", "Si el tanque necesita una cura directa.", "When the tank needs a direct heal." },
      { "Healing Touch", "Si ya tiene Regrowth puesto.", "If Regrowth is already on." },
      { "Entangling Roots", "Si la pelea se pone peligrosa: inmoviliza a uno.", "If the pull gets dangerous: root one enemy." },
      { "Moonfire", "Si te sobra mana: ayuda con el dano.", "With spare mana: help with damage." },
      { "Wrath", "Si te sobra mana, despues de Moonfire.", "With spare mana, after Moonfire." },
    },
  },
}

-- Nota fija bajo el titulo de la rotacion (lo que no es un hechizo de entrenador)
local NOTA = {
  ROGUE = { "Venenos: desde el nivel 20 (Instant Poison y Crippling Poison: nivel que piden en los datos de la beta). Si piden mision de clase y que veneno va en cada arma: aun no hay informacion de WoW Forever; se actualizara.",
            "Poisons: from level 20 (Instant Poison and Crippling Poison: required level in the beta data). Whether they need a class quest and which poison goes on each weapon: no WoW Forever info yet; it will be updated." },
  WARRIOR = { "Execute llega a nivel 24, pero al subir de nivel no compensa: gasta la ira en Heroic Strike.",
              "Execute comes at level 24, but it is not worth it while leveling: spend rage on Heroic Strike." },
  -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L13): las varitas piden estar quieto 0,5 s; L101: Auto Shot igual, pero sigue disparando durante Aimed Shot/Sniper Shot; L189: Frost Blast
  PRIEST = { "La varita (Shoot) hace casi tanto dano como tus hechizos a este nivel: usala para rematar y ahorrar mana. Desde el parche del 15-oct tienes que estar quieto 0,5 s antes de que dispare.",
             "Your wand (Shoot) does almost as much damage as your spells at this level: use it to finish and save mana. Since the Oct 15 patch you must stand still for 0.5 sec before it shoots." },
  MAGE = { "La varita (Shoot) hace casi tanto dano como tus hechizos a este nivel: usala para rematar y ahorrar mana. Desde el parche del 15-oct tienes que estar quieto 0,5 s antes de que dispare. Desde el nivel 24, Frost Blast (1,5 s, frena un 40 %) sustituye a Frostbolt de rango 1 para frenar.",
           "Your wand (Shoot) does almost as much damage as your spells at this level: use it to finish and save mana. Since the Oct 15 patch you must stand still for 0.5 sec before it shoots. From level 24, Frost Blast (1.5 sec, 40% slow) replaces rank 1 Frostbolt for slowing." },
  SHAMAN = { "Totems: para usar cada tipo necesitas su totem de mision de clase: tierra a nivel 4 (Strength of Earth Totem), fuego a nivel 10 (Searing Totem), agua a nivel 20 (Healing Stream Totem) y aire a nivel 30 (Grounding Totem).",
             "Totems: each type needs its totem from a class quest: Earth at level 4 (Strength of Earth Totem), Fire at level 10 (Searing Totem), Water at level 20 (Healing Stream Totem) and Air at level 30 (Grounding Totem)." },
  WARLOCK = { "La varita (Shoot) hace casi tanto dano como tus hechizos a este nivel: usala despues de tus danos con el tiempo. Desde el parche del 15-oct tienes que estar quieto 0,5 s antes de que dispare.",
              "Your wand (Shoot) does almost as much damage as your spells at this level: use it after your damage over time. Since the Oct 15 patch you must stand still for 0.5 sec before it shoots." },
  HUNTER = { "Auto Shot: desde el parche del 15-oct tienes que estar quieto 0,5 s antes de que dispare; sigue disparando mientras lanzas Aimed Shot.",
             "Auto Shot: since the Oct 15 patch you must stand still for 0.5 sec before it shoots; it still fires while you cast Aimed Shot." },
}

-- ===================== Macros por clase =====================
-- 16-oct (Andy: "las mejores macros de cada clase y rama, contrastadas, sin inventar"): rehechas con guias de WoW Forever.
-- { nivel, nombre (max 16), cuerpo, "para que (es)", "what (en)", "cuando (es)", "when (en)", rama = {...}, extra = {...}, uso = "...", fuente = {...} }.
-- {Hechizo} se cambia por el nombre del cliente. {A|B|C} = el primero que ya sepas (si no sabes ninguno, el de menor nivel).
-- [known:X] = hechizo opcional (la macro sirve sin el). Shoot, Tiger's Fury... van sin llaves (no estan en wowF_Hechizos).
-- extra = hechizos que la macro usa en cuanto los aprendes, sin esperarlos (no suben el nivel de la macro; al aprenderlos se avisa
--   "Ahora tu macro X tambien usa Y"). rama = solo para esas ramas (sin rama = todas). uso = "pve" | "pvp" | "ambos" (por defecto ambos).
-- fuente = { nombre, url } de la guia de WoW Forever de la que sale (obligatoria: la prueba falla sin ella o con una de Classic).
local MAC = {
  TODAS = {},
  WARRIOR = {
    { 4, "FG Carga", "#showtooltip\n/startattack\n/cast [nocombat,stance:1,@target] {Charge}; [combat,stance:3,@target] {Intercept}; [nocombat] {Battle Stance}; {Berserker Stance}",
      "Fuera de combate y en Battle Stance, Charge; ya en combate y en Berserker Stance, Intercept. Si no estas en la postura, te cambia a ella.", "Out of combat in Battle Stance, Charge; in combat in Berserker Stance, Intercept. If you are in the wrong stance, it switches you.",
      "Para abrir cada pelea desde 8 a 25 metros y para alcanzar a quien se te escapa.", "To open every fight from 8 to 25 yards and to catch whoever runs away.",
      extra = { "Intercept", "Berserker Stance" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/#charge-intercept" } },
    { 4, "FG Charge+Rend", "#showtooltip\n/startattack\n/cast [nocombat,nostance:1] {Battle Stance}\n/cast [nocombat,stance:1] {Charge}\n/cast [combat] {Rend}",
      "Te pone en Battle Stance, cargas y, ya en combate, pones Rend. Todo con un boton.", "Puts you in Battle Stance, charges and, once in combat, applies Rend. All on one button.",
      "Al empezar cada pelea mientras subes: pulsala dos veces (carga y sangrado).", "At the start of every fight while leveling: press it twice (charge, then bleed).",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-charge-rend-opener" } },
    { 10, "FG Sunder", "#showtooltip {Sunder Armor}\n/cast [mod:ctrl,@target] {Heroic Strike}\n/cast [@target] {Sunder Armor}",
      "Sunder Armor; con Ctrl pulsado, Heroic Strike a la vez.", "Sunder Armor; holding Ctrl, Heroic Strike too.",
      "Para bajar la armadura del enemigo en peleas largas o al tanquear; Ctrl cuando te sobra ira.", "To lower enemy armor in long fights or when tanking; Ctrl when you have spare Rage.",
      uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/#sunder-heroic-strike" } },
    { 20, "FG Cleave", "#showtooltip\n/startattack\n/cast {Cleave}",
      "Cleave y empiezas a atacar solo.", "Cleave and start auto-attacking.",
      "Con dos o mas enemigos pegados a ti y la ira de sobra.", "With two or more enemies on you and spare Rage.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-startattack-cleave" } },
    { 6, "FG Thunder", "#showtooltip\n/startattack\n/cast {Thunder Clap}",
      "Thunder Clap y empiezas a atacar solo.", "Thunder Clap and start auto-attacking.",
      "Con varios enemigos alrededor: les hace dano y los vuelve mas lentos.", "With several enemies around you: damages and slows them.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-thunderclap" } },
    { 20, "FG Victory", "#showtooltip\n/startattack\n/cast {Victory Rush}",
      "Victory Rush y empiezas a atacar solo.", "Victory Rush and start auto-attacking.",
      "Justo despues de matar a un enemigo: golpe gratis que te cura.", "Right after killing an enemy: a free hit that heals you.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-victory-rush" } },
    { 22, "FG Intimidating", "#showtooltip {Intimidating Shout}\n/stopattack\n/cast [@target,harm,nodead] {Intimidating Shout}",
      "Deja de atacar y lanza Intimidating Shout sobre tu objetivo.", "Stops attacking and casts Intimidating Shout on your target.",
      "Cuando te rodean demasiados enemigos o quieres separar a un jugador; deja de atacar para no romper el miedo.", "When too many enemies surround you or you want to peel a player; it stops attacking so the fear does not break.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/#shout-stop-swing" } },
    { 12, "FG Overpower", "#showtooltip\n/cast [mod:ctrl,stance:1/2,@target] {Rend}; [stance:1,@target] {Overpower}; {Battle Stance}",
      "En Battle Stance, Overpower; con Ctrl, Rend. Si no estas en Battle Stance, te cambia.", "In Battle Stance, Overpower; holding Ctrl, Rend. If you are not in Battle Stance, it switches you.",
      "Overpower cuando el enemigo esquiva (se ilumina); Rend con Ctrl al empezar la pelea.", "Overpower when the enemy dodges (it lights up); Rend with Ctrl at the start of the fight.",
      rama = { "Arms" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/arms/#arms-overpower-rend" } },
    { 20, "FG Slam", "#showtooltip [mod:ctrl] {Execute}; {Slam}\n/cast [mod:ctrl,stance:1/3,@target] {Execute}; [mod:ctrl] {Battle Stance}; [@target] {Slam}",
      "Slam; con Ctrl, Execute (te cambia de postura si hace falta).", "Slam; holding Ctrl, Execute (switches stance if needed).",
      "Slam como golpe normal; Execute con Ctrl cuando el enemigo baja del 20 % de vida.", "Slam as your normal hit; Execute with Ctrl when the enemy drops below 20 % health.",
      rama = { "Arms" }, extra = { "Execute" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/arms/#arms-slam-execute" } },
    { 30, "FG Berserker", "#showtooltip\n/cast [nostance:3] {Berserker Stance}\n/cast {Berserker Rage}",
      "Te pone en Berserker Stance y lanza Berserker Rage.", "Puts you in Berserker Stance and casts Berserker Rage.",
      "Contra miedos y para ganar ira; usala antes de que te pongan Fear.", "Against fears and to gain Rage; use it before you get Feared.",
      rama = { "Fury" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-berserker-rage" } },
    { 14, "FG Revenge", "#showtooltip {Revenge}\n/startattack\n/cast [harm,nodead] {Shield Block}\n/cast [@target] {Revenge}",
      "Shield Block y Revenge en un solo boton.", "Shield Block and Revenge on one button.",
      "Al tanquear: pulsala siempre que puedas; Revenge sale tras bloquear o esquivar.", "When tanking: press it whenever you can; Revenge is up after a block or dodge.",
      rama = { "Protection" }, extra = { "Shield Block" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/protection/#prot-revenge-block" } },
    { 10, "FG Taunt", "#showtooltip {Taunt}\n/cast [stance:2,@target,harm,nodead] {Taunt}\n/cast [@target,harm,nodead] {Sunder Armor}",
      "Taunt (en Defensive Stance) y Sunder Armor sobre tu objetivo.", "Taunt (in Defensive Stance) and Sunder Armor on your target.",
      "Cuando un enemigo se va a por otro del grupo: lo recuperas y le sumas amenaza.", "When an enemy goes for someone else in the group: you pull it back and add threat.",
      rama = { "Protection" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/protection/#prot-taunt-sunder" } },
    { 1, "FG Last Stand", "#showtooltip [mod:ctrl] {Shield Wall}; {Last Stand}\n/cast {Last Stand}\n/cast [mod:ctrl] {Shield Wall}",
      "Last Stand; con Ctrl, ademas Shield Wall.", "Last Stand; holding Ctrl, Shield Wall too.",
      "Cuando tu vida baja mucho al tanquear; Ctrl en el peor momento.", "When your health drops low while tanking; Ctrl in the worst moments.",
      rama = { "Protection" }, extra = { "Shield Wall" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warrior/protection/#prot-last-stand" } },
    { 18, "FG Disarm", "#showtooltip\n/cast [@mouseover,harm,nodead][] {Disarm}",
      "Disarm sobre el enemigo bajo el raton o sobre tu objetivo.", "Disarm on your mouseover enemy or your target.",
      "Contra un jugador de cuerpo a cuerpo cuando activa su rafaga.", "Against a melee player when they pop their burst.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warrior-disarm-mouseover" } },
  },
  PALADIN = {
    { 4, "FG Juicio", "#showtooltip\n/cast [@target,harm][harm] {Judgement}\n/startattack",
      "Judgement sobre tu objetivo y empiezas a atacar solo.", "Judgement on your target and start auto-attacking.",
      "Para abrir cada pelea y cada vez que Judgement esta listo.", "To open every fight and whenever Judgement is ready.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-judgement-startattack" } },
    { 6, "FG Holy Strike", "#showtooltip {Holy Strike}\n/targetenemy [noharm][dead]\n/startattack\n/cast [harm,nodead] {Judgement}\n/cast {Holy Strike}",
      "Busca enemigo si no tienes, ataca, lanza Judgement y Holy Strike.", "Finds an enemy if you have none, attacks, casts Judgement and Holy Strike.",
      "Tu boton principal para pegar mientras subes.", "Your main button to hit while leveling.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/#holy-strike" } },
    { 6, "FG Seal", "#showtooltip [mod:ctrl] {Judgement}; {Seal of the Crusader}\n/cast [mod:ctrl,@target,harm,nodead] {Judgement}\n/cast [mod:ctrl] {Seal of Righteousness}; {Seal of the Crusader}",
      "Seal of the Crusader; con Ctrl, Judgement y Seal of Righteousness.", "Seal of the Crusader; holding Ctrl, Judgement and Seal of Righteousness.",
      "Pon el sello antes de pelear; Ctrl para juzgar y volver a sellar.", "Put up the seal before the fight; Ctrl to judge and reseal.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/#judge-crusader" } },
    { 8, "FG Purify", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] {Purify}",
      "Purify sobre el aliado bajo el raton, tu objetivo o ti.", "Purify on your mouseover ally, your target or yourself.",
      "Para quitar un veneno o una enfermedad.", "To remove a poison or a disease.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-purify-mouseover" } },
    { 10, "FG BoP", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] {Blessing of Protection}",
      "Blessing of Protection sobre el aliado bajo el raton, tu objetivo o ti.", "Blessing of Protection on your mouseover ally, your target or yourself.",
      "Cuando un aliado (o tu) recibe golpes fisicos y va a morir.", "When an ally (or you) takes physical hits and is about to die.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-blessing-of-protection-mouseover" } },
    { 18, "FG Freedom", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] {Blessing of Freedom}",
      "Blessing of Freedom sobre el aliado bajo el raton, tu objetivo o ti.", "Blessing of Freedom on your mouseover ally, your target or yourself.",
      "Contra raices y lentitudes.", "Against roots and slows.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-blessing-of-freedom-mouseover" } },
    { 20, "FG Consecrate", "#showtooltip\n/cast {Consecration}",
      "Consecration a tus pies.", "Consecration at your feet.",
      "Con varios enemigos alrededor.", "With several enemies around you.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-consecration-aoe" } },
    { 20, "FG Exorcism", "#showtooltip\n/cast [harm][@target] {Exorcism}",
      "Exorcism sobre tu objetivo.", "Exorcism on your target.",
      "Contra no-muertos y demonios.", "Against undead and demons.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-exorcism-undead" } },
    { 8, "FG Martillo", "#showtooltip {Hammer of Justice}\n/cast [mod:ctrl,@target,harm,nodead][nomod:ctrl,@focus,harm,nodead][nomod:ctrl,@target,harm,nodead] {Hammer of Justice}",
      "Hammer of Justice sobre tu foco; con Ctrl, sobre tu objetivo.", "Hammer of Justice on your focus; holding Ctrl, on your target.",
      "Para aturdir al curador enemigo sin perder a quien atacas.", "To stun the enemy healer without losing your target.",
      uso = "pvp", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/#hoj-focus" } },
    { 20, "FG Command", "#showtooltip [mod:ctrl] {Seal of Righteousness}; {Seal of Command}\n/startattack [@target,harm,nodead]\n/cast [@target,harm,nodead] {Judgement}\n/cast [mod:ctrl] {Seal of Righteousness}; {Seal of Command}",
      "Judgement y Seal of Command; con Ctrl, Seal of Righteousness.", "Judgement and Seal of Command; holding Ctrl, Seal of Righteousness.",
      "Tu ciclo de sellos: juzga y vuelve a sellar en un boton.", "Your seal cycle: judge and reseal on one button.",
      rama = { "Retribution" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/retribution/#ret-twist" } },
    { 8, "FG Judge+Hammer", "#showtooltip [mod:ctrl] {Judgement}; {Hammer of Justice}\n/cast [mod:ctrl,@target,harm,nodead] {Judgement}; [@target,harm,nodead] {Hammer of Justice}",
      "Hammer of Justice; con Ctrl, Judgement.", "Hammer of Justice; holding Ctrl, Judgement.",
      "Aturdir para empezar tu rafaga o cortar una cura.", "Stun to start your burst or stop a heal.",
      rama = { "Retribution" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/retribution/#ret-stun-judge" } },
    { 4, "FG Swift Judge", "#showtooltip {Judgement}\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl,harm,nodead] {Swift Judgement}\n/cast [@mouseover,harm,nodead][harm,nodead] {Judgement}",
      "Judgement; con Ctrl, Swift Judgement (raton u objetivo).", "Judgement; holding Ctrl, Swift Judgement (mouseover or target).",
      "Al tanquear, para sumar amenaza a distancia.", "When tanking, to add threat at range.",
      rama = { "Protection" }, extra = { "Swift Judgement" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/protection/#taunt" } },
    { 20, "FG Flash", "#showtooltip\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {Flash of Light}",
      "Flash of Light sobre el aliado bajo el raton, tu objetivo o ti (Alt = ti).", "Flash of Light on your mouseover ally, your target or yourself (Alt = you).",
      "Tu cura rapida para dano constante.", "Your fast heal for steady damage.",
      rama = { "Holy" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#paladin-flash-of-light-mouseover" } },
    { 1, "FG Holy Light", "#showtooltip {Holy Light}\n/cast [mod:ctrl] {Voice of Truth}\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] {Holy Light}",
      "Holy Light (raton, objetivo o ti); con Ctrl, Voice of Truth antes.", "Holy Light (mouseover, target or you); holding Ctrl, Voice of Truth first.",
      "Tu cura grande cuando hay tiempo para lanzarla.", "Your big heal when there is time to cast.",
      rama = { "Holy" }, extra = { "Voice of Truth" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/holy/#holy-light-voice" } },
    { 30, "FG Holy Shock", "#showtooltip {Holy Shock}\n/cast [mod:ctrl] {Divine Favor}\n/cast [@mouseover,help,nodead][@mouseover,harm,nodead][@target,help,nodead][@target,harm,nodead][@player] {Holy Shock}",
      "Holy Shock al aliado o enemigo bajo el raton o tu objetivo; con Ctrl, Divine Favor antes.", "Holy Shock on your mouseover or target, ally or enemy; holding Ctrl, Divine Favor first.",
      "Cura o dano instantaneo; Ctrl para asegurar el critico.", "Instant heal or damage; Ctrl to guarantee the crit.",
      rama = { "Holy" }, extra = { "Divine Favor" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/holy/#holy-shock-favor" } },
    { 10, "FG Lay on Hands", "#showtooltip [mod:ctrl] {Hammer of Justice}; {Lay on Hands}\n/stopcasting\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl,@target] {Hammer of Justice}; [@mouseover,help,nodead][@target,help,nodead][@player] {Lay on Hands}",
      "Lay on Hands al aliado; con Ctrl, Hammer of Justice al enemigo.", "Lay on Hands on an ally; holding Ctrl, Hammer of Justice on an enemy.",
      "Emergencia: un aliado a punto de morir.", "Emergency: an ally about to die.",
      rama = { "Holy" }, extra = { "Hammer of Justice" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/paladin/holy/#holy-emergency" } },
  },
  HUNTER = {
    { 1, "FG Auto Shot", "#showtooltip\n/targetenemy [noexists][dead][help]\n/cast !{Auto Shot}",
      "Busca enemigo si hace falta y activa Auto Shot sin apagarlo.", "Finds an enemy if needed and turns on Auto Shot without toggling it off.",
      "Para empezar a disparar.", "To start shooting.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-autoshot-safe-target" } },
    { 6, "FG Arcane+Pet", "#showtooltip {Arcane Shot}\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] {Arcane Shot}",
      "Manda a tu mascota y lanza Arcane Shot.", "Sends your pet and casts Arcane Shot.",
      "Para abrir la pelea con tu mascota a la vez.", "To open the fight together with your pet.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/#pet-shot" } },
    { 6, "FG Arcane+Auto", "#showtooltip {Arcane Shot}\n/cast {Arcane Shot}\n/cast !{Auto Shot}",
      "Arcane Shot sin cortar el Auto Shot.", "Arcane Shot without breaking Auto Shot.",
      "Tu disparo principal mientras subes.", "Your main shot while leveling.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-arcane-shot-autoshot" } },
    { 18, "FG Multi+Auto", "#showtooltip {Multi-Shot}\n/cast {Multi-Shot}\n/cast !{Auto Shot}",
      "Multi-Shot sin cortar el Auto Shot.", "Multi-Shot without breaking Auto Shot.",
      "Con dos o mas enemigos juntos.", "With two or more enemies together.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-multishot-autoshot" } },
    { 1, "FG Raptor", "#showtooltip {Raptor Strike}\n/targetenemy [noharm][dead]\n/cast [@target,harm,nodead] {Raptor Strike}\n/cast [@target,harm,nodead] {Mongoose Bite}",
      "Raptor Strike y Mongoose Bite cuando se puede.", "Raptor Strike and Mongoose Bite when possible.",
      "Cuando un enemigo llega a cuerpo a cuerpo.", "When an enemy reaches melee range.",
      extra = { "Mongoose Bite" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/#melee" } },
    { 10, "FG Aspectos", "#showtooltip\n/cast [mod:ctrl] {Aspect of the Monkey}; [combat] {Aspect of the Hawk}; {Aspect of the Cheetah}",
      "Fuera de combate, Aspect of the Cheetah; en combate, Aspect of the Hawk; con Ctrl, Aspect of the Monkey.", "Out of combat, Aspect of the Cheetah; in combat, Aspect of the Hawk; holding Ctrl, Aspect of the Monkey.",
      "Para no cambiar de aspecto a mano: el que toca segun el momento.", "So you never swap aspects by hand: the right one for the moment.",
      extra = { "Aspect of the Cheetah" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/#aspects" } },
    { 10, "FG Mascota", "#showtooltip\n/cast [@pet,dead][mod:shift] {Revive Pet}; [nopet] {Call Pet}; {Mend Pet}",
      "Revive Pet si esta muerta (o con Mayus), Call Pet si no la tienes y Mend Pet si esta viva.", "Revive Pet if dead (or Shift), Call Pet if you have none, Mend Pet if alive.",
      "Un solo boton para todo lo de tu mascota.", "One button for everything about your pet.",
      extra = { "Mend Pet" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-call-revive-mend-pet" } },
    { 10, "FG Feed Pet", "#showtooltip {Feed Pet}\n/cast [pet,nocombat] {Feed Pet}",
      "Feed Pet fuera de combate.", "Feed Pet out of combat.",
      "Entre peleas, para que tu mascota este contenta.", "Between fights, to keep your pet happy.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-feed-pet" } },
    { 30, "FG Fingir", "#showtooltip {Feign Death}\n/stopcasting\n/petfollow [mod:ctrl]\n/cast {Feign Death}",
      "Corta lo que lanzas y Feign Death; con Ctrl, ademas tu mascota vuelve.", "Stops casting and Feign Death; holding Ctrl, your pet also comes back.",
      "Para quitarte el enemigo de encima.", "To drop the enemy off you.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/#feign" } },
    { 30, "FG Trap+Feign", "#showtooltip {Freezing Trap}\n/petpassive\n/petstay [@pettarget,harm]\n/stopattack\n/cast [combat] {Feign Death}\n/cast {Freezing Trap}",
      "Mascota pasiva, deja de atacar, Feign Death en combate y Freezing Trap.", "Pet passive, stop attacking, Feign Death in combat and Freezing Trap.",
      "Para poner una trampa en plena pelea contra un jugador.", "To drop a trap mid-fight against a player.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-freezing-trap-chain" } },
    { 20, "FG Disengage", "#showtooltip {Disengage}\n/cast {Disengage}",
      "Disengage.", "Disengage.",
      "Para separarte de un enemigo de cuerpo a cuerpo.", "To get away from a melee enemy.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-disengage" } },
    { 30, "FG Intimidation", "#showtooltip {Intimidation}\n/petattack [@target,harm,nodead]\n/cast [harm,nodead] {Intimidation}",
      "Manda a tu mascota y lanza Intimidation.", "Sends your pet and casts Intimidation.",
      "Para aturdir y cortar un lanzamiento o salvarte.", "To stun and stop a cast or save yourself.",
      rama = { "Beast Mastery" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/beast-mastery/#bm-intim" } },
    { 6, "FG Mark+Sting", "#showtooltip\n/cast [mod:ctrl,@target,harm,nodead][nocombat,@target,harm,nodead] {Hunter's Mark}; [@target,harm,nodead] {Serpent Sting}",
      "Fuera de combate (o con Ctrl), Hunter's Mark; en combate, Serpent Sting.", "Out of combat (or Ctrl), Hunter's Mark; in combat, Serpent Sting.",
      "Para abrir: marca y luego veneno, en el mismo boton.", "To open: mark, then sting, on the same button.",
      rama = { "Marksmanship" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/marksmanship/#mm-mark-sting" } },
    { 20, "FG Rapid+Aimed", "#showtooltip [mod:ctrl] {Multi-Shot}; {Aimed Shot}\n/cast [harm,nodead] {Rapid Fire}\n/cast [mod:ctrl,@target,harm,nodead] {Multi-Shot}; [@target,harm,nodead] {Aimed Shot}",
      "Rapid Fire y Aimed Shot; con Ctrl, Multi-Shot.", "Rapid Fire and Aimed Shot; holding Ctrl, Multi-Shot.",
      "Tu rafaga de dano en peleas largas.", "Your damage burst in long fights.",
      rama = { "Marksmanship" }, extra = { "Rapid Fire", "Multi-Shot" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/marksmanship/#mm-aimed" } },
    { 20, "FG Aimed+Auto", "#showtooltip {Aimed Shot}\n/targetenemy [noharm]\n/cast {Aimed Shot}\n/cast !{Auto Shot}",
      "Aimed Shot sin cortar el Auto Shot.", "Aimed Shot without breaking Auto Shot.",
      "Tu golpe fuerte entre disparos.", "Your big hit between shots.",
      rama = { "Marksmanship" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#hunter-aimed-shot-autoshot" } },
    { 30, "FG Scatter", "#showtooltip [mod:ctrl] {Freezing Trap}; {Scatter Shot}\n/stopcasting\n/cast [mod:ctrl] {Freezing Trap}; [@target,harm,nodead] {Scatter Shot}",
      "Scatter Shot; con Ctrl, Freezing Trap.", "Scatter Shot; holding Ctrl, Freezing Trap.",
      "Contra un jugador: lo desorientas y le pones la trampa.", "Against a player: disorient them and trap them.",
      rama = { "Marksmanship" }, uso = "pvp", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/marksmanship/#mm-scatter" } },
    { 12, "FG Wing Clip", "#showtooltip [mod:ctrl] {Wing Clip}; {Strider Kick}\n/targetenemy [noharm][dead]\n/cast [@target,harm,nodead] {Raptor Strike}\n/cast [mod:ctrl,@target,harm,nodead] {Wing Clip}; [@target,harm,nodead] {Strider Kick}",
      "Raptor Strike y Strider Kick; con Ctrl, Wing Clip.", "Raptor Strike and Strider Kick; holding Ctrl, Wing Clip.",
      "A cuerpo a cuerpo: pega y frena al enemigo.", "In melee: hit and slow the enemy.",
      rama = { "Survival" }, extra = { "Strider Kick" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/survival/#sv-strike" } },
    { 30, "FG Counter", "#showtooltip {Counterattack}\n/cast [mod:ctrl,harm,nodead] {Deterrence}\n/cast [@target,harm,nodead] {Counterattack}",
      "Counterattack; con Ctrl, Deterrence.", "Counterattack; holding Ctrl, Deterrence.",
      "Tras parar un golpe, Counterattack; Deterrence cuando te pegan mucho.", "After a parry, Counterattack; Deterrence when you take heavy hits.",
      rama = { "Survival" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/hunter/survival/#sv-counter" } },
  },
  ROGUE = {
    { 1, "FG Abrir", "#showtooltip\n/cast [stealth,@target] {Cheap Shot}; [@target,harm,nodead] {Sinister Strike}",
      "En Stealth, Cheap Shot; fuera de Stealth, Sinister Strike.", "In Stealth, Cheap Shot; out of Stealth, Sinister Strike.",
      "Para abrir aturdiendo y seguir con el golpe normal en el mismo boton.", "To open with a stun and keep hitting on the same button.",
      extra = { "Cheap Shot" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/#macro-stealth-opener" } },
    { 1, "FG Sinister", "#showtooltip\n/startattack\n/cast {Sinister Strike}",
      "Empiezas a atacar y Sinister Strike.", "Start attacking and Sinister Strike.",
      "Tu golpe normal para sumar puntos de combo.", "Your normal hit to build combo points.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 4, "FG Backstab", "#showtooltip\n/startattack\n/cast {Backstab}",
      "Empiezas a atacar y Backstab.", "Start attacking and Backstab.",
      "Con daga y a la espalda del enemigo.", "With a dagger, from behind the enemy.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 10, "FG Slice Dice", "#showtooltip\n/cast {Slice and Dice}",
      "Slice and Dice.", "Slice and Dice.",
      "Mantenlo puesto: mas velocidad de ataque.", "Keep it up: more attack speed.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 1, "FG Eviscerate", "#showtooltip\n/startattack\n/cast {Eviscerate}",
      "Empiezas a atacar y Eviscerate.", "Start attacking and Eviscerate.",
      "Remate con 4-5 puntos de combo.", "Finisher with 4-5 combo points.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Rupture", "#showtooltip\n/startattack\n/cast {Rupture}",
      "Empiezas a atacar y Rupture.", "Start attacking and Rupture.",
      "Remate de sangrado en peleas largas.", "Bleed finisher in long fights.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 16, "FG Feint", "#showtooltip {Feint}\n/cast [mod:ctrl] {Evasion}\n/cast [@target,harm,nodead] {Feint}",
      "Feint; con Ctrl, Evasion.", "Feint; holding Ctrl, Evasion.",
      "Feint en grupo para bajar amenaza; Evasion cuando te pegan.", "Feint in a group to drop threat; Evasion when you get hit.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/#macro-feint-evasion" } },
    { 12, "FG Kick", "#showtooltip {Kick}\n/cast [mod:ctrl,@target,harm,nodead][nomod:ctrl,@focus,harm,nodead][nomod:ctrl,@target,harm,nodead] {Kick}",
      "Kick sobre tu foco o tu objetivo; con Ctrl, siempre tu objetivo.", "Kick on your focus or target; holding Ctrl, always your target.",
      "Para cortar un hechizo enemigo.", "To interrupt an enemy spell.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/#macro-kick-focus" } },
    { 10, "FG Sap", "#showtooltip\n/cleartarget\n/targetenemy [noexists]\n/cast {Sap}\n/cast [nostealth] {Stealth}",
      "Elige un enemigo, Sap, y vuelve a Stealth si lo perdiste.", "Picks an enemy, Sap, and back into Stealth if you lost it.",
      "Para dormir a un enemigo antes de la pelea.", "To put an enemy to sleep before the fight.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 22, "FG Vanish", "/stopattack\n/cast [combat] {Vanish}; [nostealth] {Stealth}",
      "Deja de atacar; en combate, Vanish; fuera, Stealth.", "Stop attacking; in combat, Vanish; out of combat, Stealth.",
      "Para escapar o volver a abrir.", "To escape or open again.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 12, "FG Kick Mouse", "#showtooltip {Kick}\n/cast [@mouseover,harm,nodead][harm,nodead] {Kick}",
      "Kick sobre el enemigo bajo el raton o tu objetivo.", "Kick on your mouseover enemy or target.",
      "Para cortar a un curador sin cambiar de objetivo.", "To interrupt a healer without changing target.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 30, "FG Kidney", "#showtooltip\n/cast {Kidney Shot}",
      "Kidney Shot.", "Kidney Shot.",
      "Remate que aturde; tras Cheap Shot para encadenar.", "Stunning finisher; after Cheap Shot to chain stuns.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 1, "FG Cold Blood", "#showtooltip {Eviscerate}\n/cast [mod:ctrl,harm,nodead] {Cold Blood}\n/cast [@target] {Eviscerate}",
      "Eviscerate; con Ctrl, Cold Blood antes.", "Eviscerate; holding Ctrl, Cold Blood first.",
      "Remate con critico asegurado.", "Finisher with a guaranteed crit.",
      rama = { "Assassination" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/assassination/#macro-cold-blood-eviscerate" } },
    { 18, "FG Ambush", "#showtooltip {Ambush}\n/cast [stealth,harm,nodead] {Cold Blood}\n/cast [stealth,@target] {Ambush}",
      "En Stealth, Cold Blood y Ambush.", "In Stealth, Cold Blood and Ambush.",
      "Para abrir con el golpe mas fuerte.", "To open with the hardest hit.",
      rama = { "Assassination" }, extra = { "Cold Blood" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/assassination/#macro-cold-blood-ambush" } },
    -- 3-nov (build 1.60.1.70755): Mutilate paso a la fila 7 (nivel 40), fuera del tope de 30: se quito "FG Mutilate" (Rankedboost)
    { 1, "FG Blade Flurry", "#showtooltip {Blade Flurry}\n/cancelaura [mod:ctrl] {Blade Flurry}\n/cast [nomod:ctrl] {Blade Flurry}",
      "Blade Flurry; con Ctrl, lo quitas.", "Blade Flurry; holding Ctrl, you cancel it.",
      "Con dos enemigos cerca; quitalo para no despertar ovejas.", "With two enemies close; cancel it so you do not break sheep.",
      rama = { "Combat" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/combat/#macro-blade-flurry-cancel" } },
    { 10, "FG Sprint+Gouge", "#showtooltip {Sprint}\n/cast {Sprint}\n/cast [@target,harm,nodead] {Gouge}",
      "Sprint y Gouge sobre tu objetivo.", "Sprint and Gouge on your target.",
      "Para llegar y aturdir a quien huye.", "To reach and incapacitate someone running.",
      rama = { "Combat" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/combat/#macro-sprint-gouge-escape" } },
    { 20, "FG Premeditate", "#showtooltip\n/cast [stealth,@target] {Premeditation}\n/cast [stealth,mod:ctrl,@target] {Cheap Shot}; [stealth,@target] {Ambush}; [@target,harm,nodead] {Backstab}",
      "En Stealth, Premeditation y Ambush (Ctrl: Cheap Shot); fuera, Backstab.", "In Stealth, Premeditation and Ambush (Ctrl: Cheap Shot); out of it, Backstab.",
      "Tu apertura completa en un boton.", "Your full opener on one button.",
      rama = { "Subtlety" }, extra = { "Cheap Shot" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/subtlety/#macro-premeditation-opener" } },
    { 8, "FG Ghostly", "#showtooltip {Evasion}\n/cast [harm,nodead] {Evasion}\n/cast [@target,harm,nodead] {Ghostly Strike}",
      "Evasion y Ghostly Strike.", "Evasion and Ghostly Strike.",
      "Cuando te pega un enemigo cuerpo a cuerpo.", "When a melee enemy hits you.",
      rama = { "Subtlety" }, extra = { "Ghostly Strike" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/subtlety/#macro-evasion-ghostly-strike" } },
    { 22, "FG Vanish+Prep", "#showtooltip {Vanish}\n/cast {Vanish}\n/cast [mod:ctrl] {Preparation}",
      "Vanish; con Ctrl, Preparation.", "Vanish; holding Ctrl, Preparation.",
      "Para escapar; Preparation te devuelve Vanish.", "To escape; Preparation gives you Vanish back.",
      rama = { "Subtlety" }, extra = { "Preparation" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/rogue/subtlety/#macro-vanish-preparation" } },
  },
  PRIEST = {
    { 6, "FG Escudo", "#showtooltip {Power Word: Shield}\n/stopcasting\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] {Power Word: Shield}",
      "Corta lo que lanzas y Power Word: Shield (raton, objetivo o ti).", "Stops casting and Power Word: Shield (mouseover, target or you).",
      "Primera respuesta ante cualquier golpe.", "Your first answer to any hit.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/#macro-shield" } },
    { 8, "FG Renew", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] {Renew}",
      "Renew (raton, objetivo o ti).", "Renew (mouseover, target or you).",
      "Mantenlo puesto mientras te mueves.", "Keep it up while moving.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 4, "FG Pain", "#showtooltip\n/cast [@mouseover,harm,nodead][harm,nodead] {Shadow Word: Pain}",
      "Shadow Word: Pain sobre el enemigo bajo el raton o tu objetivo.", "Shadow Word: Pain on your mouseover enemy or target.",
      "Para dejar el dano en el tiempo en varios enemigos.", "To spread damage over time on several enemies.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 14, "FG Scream", "#showtooltip {Psychic Scream}\n/stopcasting\n/cast {Psychic Scream}",
      "Corta lo que lanzas y Psychic Scream.", "Stops casting and Psychic Scream.",
      "Cuando te rodean enemigos.", "When enemies surround you.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/#macro-psychic-scream" } },
    { 8, "FG Fade", "#showtooltip {Fade}\n/stopcasting\n/cast {Fade}",
      "Corta lo que lanzas y Fade.", "Stops casting and Fade.",
      "En grupo, cuando un enemigo se va a por ti.", "In a group, when an enemy turns on you.",
      uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/#macro-fade" } },
    { 20, "FG Shackle", "#showtooltip {Shackle Undead}\n/focus [@focus,noexists][@focus,harm,dead][mod:ctrl] target\n/cast [@focus,harm,nodead][@target,harm,nodead] {Shackle Undead}",
      "Shackle Undead sobre tu foco (Ctrl: tu objetivo pasa a foco).", "Shackle Undead on your focus (Ctrl: your target becomes focus).",
      "Para controlar a un no-muerto en mazmorra.", "To control an undead in a dungeon.",
      uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/#macro-shackle-focus" } },
    { 18, "FG Dispel", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@mouseover,harm][harm] {Dispel Magic}",
      "Dispel Magic: limpia al aliado o quita un efecto al enemigo (raton u objetivo).", "Dispel Magic: cleans an ally or strips an enemy (mouseover or target).",
      "Contra un efecto magico.", "Against a magic effect.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Fear Ward", "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][target=player] {Fear Ward}",
      "Fear Ward (raton, objetivo o ti).", "Fear Ward (mouseover, target or you).",
      "Antes de un miedo conocido.", "Before a known fear.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 24, "FG Mana Burn", "#showtooltip\n/cast [harm][@target] {Mana Burn}",
      "Mana Burn sobre tu objetivo.", "Mana Burn on your target.",
      "Contra un curador o lanzador enemigo.", "Against an enemy healer or caster.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Flash Heal", "#showtooltip\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {Flash Heal}",
      "Flash Heal (raton, objetivo o ti; Alt = ti).", "Flash Heal (mouseover, target or you; Alt = you).",
      "Cura rapida para dano fuerte.", "Fast heal for heavy damage.",
      rama = { "Discipline", "Holy" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 30, "FG Prayer", "#showtooltip {Prayer of Healing}\n/cast [mod:ctrl] {Inner Focus}\n/cast [@mouseover,help,nodead][help,nodead][@player] {Prayer of Healing}",
      "Prayer of Healing; con Ctrl, Inner Focus antes.", "Prayer of Healing; holding Ctrl, Inner Focus first.",
      "Cuando hay dano en todo el grupo.", "When the whole group takes damage.",
      rama = { "Discipline" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/discipline/#macro-prayer-burst" } },
    { 30, "FG Penance", "#showtooltip {Penance}\n/stopcasting [nochanneling:Penance]\n/cast [@mouseover,help,nodead][@target,help,nodead][@target,harm,nodead] {Penance}",
      "Penance al aliado o enemigo (raton u objetivo).", "Penance on an ally or enemy (mouseover or target).",
      "Cura fuerte o dano, sin cortarlo a medias.", "Strong heal or damage, without cutting it.",
      rama = { "Discipline" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/discipline/#macro-disc-penance" } },
    { 20, "FG Holy Nova", "#showtooltip {Holy Nova}\n/stopcasting\n/cast {Holy Nova}",
      "Corta lo que lanzas y Holy Nova.", "Stops casting and Holy Nova.",
      "Grupo pegado recibiendo dano.", "Group stacked and taking damage.",
      rama = { "Holy" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/holy/#macro-holy-nova" } },
    { 20, "FG Mind Flay", "#showtooltip\n/cast [harm][@target] {Mind Flay}",
      "Mind Flay sobre tu objetivo.", "Mind Flay on your target.",
      "Tu canalizado principal.", "Your main channel.",
      rama = { "Shadow" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 1, "FG Silence", "#showtooltip {Silence}\n/stopcasting\n/cast [@target,harm,nodead] {Silence}",
      "Corta lo que lanzas y Silence.", "Stops casting and Silence.",
      "Para cortar un hechizo enemigo.", "To interrupt an enemy spell.",
      rama = { "Shadow" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/shadow/#macro-silence" } },
    { 20, "FG Flash Shadow", "#showtooltip {Flash Heal}\n/cancelform\n/cast [@mouseover,help,nodead][help,nodead][@player] {Flash Heal}",
      "Sale de Shadowform y Flash Heal (raton, objetivo o ti).", "Leaves Shadowform and Flash Heal (mouseover, target or you).",
      "Cuando te tienes que curar en Shadow.", "When you need to heal as Shadow.",
      rama = { "Shadow" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/priest/shadow/#macro-shadow-heal" } },
  },
  SHAMAN = {
    { 4, "FG Interrumpir", "#showtooltip\n/stopcasting\n/cast [@target,harm][harm] {Earth Shock}",
      "Corta lo que lanzas y Earth Shock.", "Stops casting and Earth Shock.",
      "Para cortar un hechizo enemigo.", "To interrupt an enemy spell.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 12, "FG Purge", "#showtooltip\n/cast [@target,harm,nodead] {Purge}; [@target,help,nodead][@player] {Cure Poison}",
      "Purge al enemigo; si es aliado (o nadie), Cure Poison.", "Purge on an enemy; on an ally (or none), Cure Poison.",
      "Quitar un efecto magico al enemigo o un veneno al aliado.", "Strip a magic effect from an enemy or a poison from an ally.",
      extra = { "Cure Poison" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/#macro-purge-cleanse" } },
    { 8, "FG Light Shield", "#showtooltip\n/cast {Lightning Shield}",
      "Lightning Shield.", "Lightning Shield.",
      "Mantenlo puesto siempre.", "Keep it up at all times.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 1, "FG Healing Wave", "#showtooltip\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {Healing Wave}",
      "Healing Wave (raton, objetivo o ti; Alt = ti).", "Healing Wave (mouseover, target or you; Alt = you).",
      "Tu cura grande.", "Your big heal.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Ghost Wolf", "#showtooltip\n/cast {Ghost Wolf}",
      "Ghost Wolf.", "Ghost Wolf.",
      "Para viajar mas rapido.", "To travel faster.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Call Elements", "#showtooltip\n/cast {Call of the Elements}",
      "Call of the Elements: tus totems a la vez.", "Call of the Elements: all your totems at once.",
      "Al empezar una pelea larga.", "At the start of a long fight.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 10, "FG Fire Totems", "#showtooltip\n/castsequence reset=combat {Searing Totem}, {Magma Totem}",
      "Searing Totem y luego Magma Totem.", "Searing Totem, then Magma Totem.",
      "Contra grupos de enemigos.", "Against groups of enemies.",
      extra = { "Magma Totem" }, uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 12, "FG Fire Nova", "#showtooltip\n/cast {Fire Nova}",
      "Fire Nova.", "Fire Nova.",
      "Varios enemigos cerca.", "Several enemies close.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 18, "FG Tremor", "#showtooltip [mod:ctrl] {Tremor Totem}; {Grounding Totem}\n/stopcasting\n/cast [mod:ctrl] {Tremor Totem}; {Grounding Totem}",
      "Grounding Totem; con Ctrl, Tremor Totem.", "Grounding Totem; holding Ctrl, Tremor Totem.",
      "Contra lanzadores o miedos.", "Against casters or fears.",
      extra = { "Grounding Totem" }, uso = "pvp", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/#macro-grounding-tremor" } },
    { 20, "FG Lesser Wave", "#showtooltip\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {Lesser Healing Wave}",
      "Lesser Healing Wave (raton, objetivo o ti; Alt = ti).", "Lesser Healing Wave (mouseover, target or you; Alt = you).",
      "Cura rapida entre peleas o en apuros.", "Quick heal between fights or in trouble.",
      rama = { "Enhancement", "Elemental" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 20, "FG Frost Shock", "#showtooltip\n/cast [harm][@target] {Frost Shock}",
      "Frost Shock sobre tu objetivo.", "Frost Shock on your target.",
      "Para frenar a quien huye.", "To slow someone running.",
      rama = { "Enhancement", "Restoration" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/" } },
    { 10, "FG Shocks", "#showtooltip [mod:ctrl] {Earth Shock}; {Flame Shock}\n/startattack\n/cast [mod:ctrl,@target,harm,nodead] {Earth Shock}; [@target,harm,nodead] {Flame Shock}",
      "Flame Shock; con Ctrl, Earth Shock.", "Flame Shock; holding Ctrl, Earth Shock.",
      "Tus choques en un boton.", "Your shocks on one button.",
      rama = { "Enhancement" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/enhancement/#macro-enh-melee-shocks" } },
    { 1, "FG Bolt+Frost", "#showtooltip [mod:ctrl] {Frost Shock}; {Lightning Bolt}\n/stopcasting [mod:ctrl]\n/cast [mod:ctrl,@target,harm,nodead] {Frost Shock}; [@target,harm,nodead] {Lightning Bolt}",
      "Lightning Bolt; con Ctrl, Frost Shock.", "Lightning Bolt; holding Ctrl, Frost Shock.",
      "Tu dano principal; Ctrl para frenar.", "Your main damage; Ctrl to slow.",
      rama = { "Elemental" }, extra = { "Frost Shock" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/elemental/#macro-ele-bolt-frost" } },
    -- 3-nov: Blizzard elimina Lava Burst al lanzamiento (us.forums.blizzard.com/en/wow/t/2360696/9, post del 3-nov): fuera la macro "FG Lava Burst"
    { 6, "FG Earthbind", "#showtooltip {Earthbind Totem}\n/stopcasting\n/cast {Earthbind Totem}",
      "Corta lo que lanzas y Earthbind Totem.", "Stops casting and Earthbind Totem.",
      "Contra melee que se te acerca.", "Against melee closing in.",
      rama = { "Elemental" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/elemental/#macro-ele-earthbind-root" } },
    { 1, "FG NS+Wave", "#showtooltip {Healing Wave}\n/cast {Nature's Swiftness}\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] {Healing Wave}",
      "Nature's Swiftness y Healing Wave al instante.", "Nature's Swiftness and an instant Healing Wave.",
      "Emergencia: cura grande al momento.", "Emergency: big heal instantly.",
      rama = { "Restoration" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/restoration/#macro-ns-heal" } },
    { 20, "FG LHW Target", "#showtooltip {Lesser Healing Wave}\n/cast [@target,help,nodead][@targettarget,help,nodead][@player] {Lesser Healing Wave}",
      "Lesser Healing Wave al objetivo, al objetivo de tu objetivo o a ti.", "Lesser Healing Wave on your target, its target or you.",
      "Curar al tanque mientras miras al enemigo.", "Heal the tank while targeting the enemy.",
      rama = { "Restoration" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/shaman/restoration/#macro-resto-victim-heal" } },
  },
  MAGE = {
    { 6, "FG Remate", "#showtooltip {Fire Blast}\n/stopcasting\n/cast [@target,harm,nodead] {Fire Blast}",
      "Corta lo que lanzas y Fire Blast.", "Stops casting and Fire Blast.",
      "Para rematar o pegar mientras te mueves.", "To finish off or hit while moving.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/#macro-fire-blast-finisher" } },
    { 10, "FG Nova", "#showtooltip\n/stopcasting\n/cast [mod:ctrl] {Blink}; {Frost Nova}",
      "Corta lo que lanzas y Frost Nova; con Ctrl, Blink.", "Stops casting and Frost Nova; holding Ctrl, Blink.",
      "Congela al melee y alejate.", "Freeze the melee and get away.",
      extra = { "Blink" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/#macro-escape" } },
    { 24, "FG Counterspell", "#showtooltip {Counterspell}\n/stopcasting\n/cast [@target,harm,nodead] {Counterspell}",
      "Corta lo que lanzas y Counterspell.", "Stops casting and Counterspell.",
      "Para cortar un hechizo enemigo.", "To interrupt an enemy spell.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/#macro-counterspell" } },
    { 8, "FG Missiles", "#showtooltip {Arcane Missiles}\n/cast [nochanneling:Arcane Missiles,@target,harm,nodead] {Arcane Missiles}",
      "Arcane Missiles sin cortarlo si ya lo canalizas.", "Arcane Missiles without clipping it.",
      "Tu dano en peleas largas.", "Your damage in long fights.",
      uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/#macro-arcane-missiles-mash" } },
    { 14, "FG Explosion", "#showtooltip {Arcane Explosion}\n/cast {Arcane Explosion}",
      "Arcane Explosion.", "Arcane Explosion.",
      "Grupos de enemigos pegados.", "Stacked groups of enemies.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-arcane-explosion-combat" } },
    { 1, "FG Varita", "#showtooltip 18\n/cast !Shoot",
      "Dispara la varita sin apagarla.", "Shoots your wand without toggling it off.",
      "Para ahorrar mana al final de cada pelea.", "To save mana at the end of each fight.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-wand-noswitch" } },
    { 1, "FG Intellect", "#showtooltip {Arcane Intellect}\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] {Arcane Intellect}",
      "Arcane Intellect (raton, objetivo o ti; Alt = ti).", "Arcane Intellect (mouseover, target or you; Alt = you).",
      "Antes de pelear.", "Before fighting.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-arcane-intellect-friend" } },
    { 18, "FG Decurse", "#showtooltip {Remove Lesser Curse}\n/cast [mod:shift,@player][@mouseover,help,nodead][help,nodead][@player] {Remove Lesser Curse}",
      "Remove Lesser Curse (raton, objetivo o ti; Mayus = ti).", "Remove Lesser Curse (mouseover, target or you; Shift = you).",
      "Para quitar una maldicion.", "To remove a curse.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-remove-lesser-curse-friend" } },
    { 8, "FG Polymorph", "#showtooltip {Polymorph}\n/cast [@mouseover,harm,nodead][] {Polymorph}",
      "Polymorph sobre el enemigo bajo el raton o tu objetivo.", "Polymorph on your mouseover enemy or target.",
      "Oveja a un segundo enemigo sin cambiar de objetivo.", "Sheep a second enemy without changing target.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-polymorph-mouseover" } },
    { 24, "FG PoM Sheep", "#showtooltip {Polymorph}\n/stopcasting\n/stopmacro [@target,noharm][@target,dead]\n/cast [@target] {Counterspell}\n/cast {Presence of Mind}\n/cast [@target] {Polymorph}",
      "Counterspell, Presence of Mind y Polymorph instantaneo.", "Counterspell, Presence of Mind and an instant Polymorph.",
      "Contra un lanzador: corta y controla al momento.", "Against a caster: interrupt and control instantly.",
      rama = { "Arcane" }, uso = "pvp", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/arcane/#macro-arcane-lockdown" } },
    { 20, "FG Pyroblast", "#showtooltip {Pyroblast}\n/stopmacro [@target,noharm][@target,dead]\n/use 13\n/use 14\n/cast [@target] {Pyroblast}",
      "Usa tus abalorios y Pyroblast.", "Uses your trinkets and Pyroblast.",
      "Para abrir la pelea con tu mayor golpe.", "To open the fight with your biggest hit.",
      rama = { "Fire" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/fire/#macro-fire-pyroblast-opener" } },
    { 22, "FG Scorch", "#showtooltip {Scorch}\n/cast [@mouseover,harm,nodead][] {Scorch}",
      "Scorch sobre el enemigo bajo el raton o tu objetivo.", "Scorch on your mouseover enemy or target.",
      "Para mantener tu dano de fuego en movimiento.", "To keep your fire damage while moving.",
      rama = { "Fire" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-scorch-mouseover" } },
    { 30, "FG Blast Wave", "#showtooltip {Blast Wave}\n/stopcasting\n/cast {Blast Wave}",
      "Corta lo que lanzas y Blast Wave.", "Stops casting and Blast Wave.",
      "Varios enemigos cerca de ti.", "Several enemies close to you.",
      rama = { "Fire" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/fire/#macro-fire-blast-wave" } },
    { 20, "FG Ice Lance", "#showtooltip {Ice Lance}\n/stopcasting\n/cast [@target,harm,nodead] {Ice Lance}",
      "Corta lo que lanzas y Ice Lance.", "Stops casting and Ice Lance.",
      "Contra un enemigo congelado.", "Against a frozen enemy.",
      rama = { "Frost" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/frost/#macro-frost-ice-lance" } },
    { 26, "FG Cone of Cold", "#showtooltip {Cone of Cold}\n/cast {Cone of Cold}",
      "Cone of Cold.", "Cone of Cold.",
      "Para frenar a varios enemigos.", "To slow several enemies.",
      rama = { "Frost" }, uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#mage-cone-of-cold" } },
    { 4, "FG Ice Block", "#showtooltip {Ice Block}\n/stopcasting [nomod:ctrl]\n/cancelaura [mod:ctrl] {Ice Block}\n/cast [nomod:ctrl] {Ice Block}",
      "Ice Block; con Ctrl, lo quitas.", "Ice Block; holding Ctrl, you cancel it.",
      "Para salvarte de morir.", "To save yourself from dying.",
      rama = { "Frost" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/mage/frost/#macro-ice-block" } },
  },
  WARLOCK = {
    { 1, "FG Shadow Bolt", "#showtooltip {Shadow Bolt}\n/petfollow [mod:ctrl]\n/stopmacro [mod:ctrl]\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] {Shadow Bolt}",
      "Manda a tu demonio y Shadow Bolt; con Ctrl, tu demonio vuelve.", "Sends your demon and Shadow Bolt; holding Ctrl, your demon comes back.",
      "Tu golpe principal con el demonio a la vez.", "Your main hit with your demon together.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/#macro-pet-send-nuke" } },
    { 8, "FG DoTs", "#showtooltip\n/petattack [harm,nodead]\n/castsequence reset=target {Immolate}, {Bane of Agony}, {Corruption}, !Shoot",
      "Manda a tu demonio y pone Immolate, Bane of Agony y Corruption; despues, varita.", "Sends your demon and applies Immolate, Bane of Agony and Corruption; then wand.",
      "Pulsala varias veces en cada enemigo mientras subes.", "Press it several times on each enemy while leveling.",
      uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warlock-dot-sequence-leveling" } },
    { 6, "FG Life Tap", "#showtooltip {Life Tap}\n/cast {Life Tap}",
      "Life Tap.", "Life Tap.",
      "Entre peleas para recuperar mana.", "Between fights to recover mana.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warlock-life-tap" } },
    { 8, "FG Miedo", "#showtooltip [mod:ctrl] {Banish}; {Fear}\n/petfollow\n/cast [mod:ctrl,@target,harm,nodead] {Banish}; [@target,harm,nodead] {Fear}",
      "Tu demonio vuelve y Fear; con Ctrl, Banish.", "Your demon comes back and Fear; holding Ctrl, Banish.",
      "Para quitarte un enemigo de encima.", "To get an enemy off you.",
      extra = { "Banish" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/#macro-cc-recall" } },
    { 8, "FG Fear Mouse", "#showtooltip {Fear}\n/cast [@mouseover,harm,nodead][] {Fear}",
      "Fear sobre el enemigo bajo el raton o tu objetivo.", "Fear on your mouseover enemy or target.",
      "Fear a un segundo enemigo sin cambiar de objetivo.", "Fear a second enemy without changing target.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warlock-fear-mouseover" } },
    { 10, "FG Demons", "#showtooltip {Summon Voidwalker}\n/cast [mod:shift] {Summon Imp}; [mod:ctrl] {Summon Succubus}; [mod:alt] {Summon Felhunter}; {Summon Voidwalker}",
      "Voidwalker; Mayus = Imp, Ctrl = Succubus, Alt = Felhunter.", "Voidwalker; Shift = Imp, Ctrl = Succubus, Alt = Felhunter.",
      "Para invocar el demonio que toca.", "To summon the right demon.",
      extra = { "Summon Succubus", "Summon Felhunter" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warlock-summon-demon-modifier" } },
    { 20, "FG Curses", "#showtooltip {Curse of the Elements}\n/cast [mod:shift] {Curse of Weakness}; [mod:ctrl] {Curse of Recklessness}; [mod:alt] {Curse of Tongues}; {Curse of the Elements}",
      "Curse of the Elements; Mayus = Weakness, Ctrl = Recklessness, Alt = Tongues.", "Curse of the Elements; Shift = Weakness, Ctrl = Recklessness, Alt = Tongues.",
      "Tus maldiciones en un boton.", "Your curses on one button.",
      extra = { "Curse of Tongues" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#warlock-pick-curse-modifier" } },
    { 8, "FG Agony", "#showtooltip [mod:ctrl] {Curse of Weakness}; {Bane of Agony}\n/cast [harm,nodead] {Amplify Curse}\n/cast [mod:ctrl,@target,harm,nodead] {Curse of Weakness}; [@target,harm,nodead] {Bane of Agony}",
      "Amplify Curse y Bane of Agony; con Ctrl, Curse of Weakness.", "Amplify Curse and Bane of Agony; holding Ctrl, Curse of Weakness.",
      "Al empezar la pelea.", "At the start of the fight.",
      rama = { "Affliction" }, extra = { "Amplify Curse" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/affliction/#macro-affli-amplify-bane" } },
    { 14, "FG Drain", "#showtooltip [mod:ctrl] {Drain Soul}; {Drain Life}\n/cast [mod:ctrl,nochanneling:Drain Soul,@target,harm,nodead] {Drain Soul}; [nomod:ctrl,nochanneling,@target,harm,nodead] {Drain Life}",
      "Drain Life; con Ctrl, Drain Soul.", "Drain Life; holding Ctrl, Drain Soul.",
      "Para curarte pegando; Drain Soul al final.", "To heal while hitting; Drain Soul at the end.",
      rama = { "Affliction" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/affliction/#macro-affli-drain" } },
    { 1, "FG Exhaustion", "#showtooltip {Curse of Exhaustion}\n/stopcasting\n/cast [@target,harm,nodead] {Curse of Exhaustion}",
      "Corta lo que lanzas y Curse of Exhaustion.", "Stops casting and Curse of Exhaustion.",
      "Para frenar a quien te persigue.", "To slow whoever chases you.",
      rama = { "Affliction" }, uso = "pvp", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/affliction/#macro-affli-exhaust-kite" } },
    { 10, "FG Fel Dom", "#showtooltip [mod:ctrl] {Summon Felhunter}; {Summon Voidwalker}\n/cast [combat] {Fel Domination}\n/cast [mod:ctrl] {Summon Felhunter}; {Summon Voidwalker}",
      "En combate, Fel Domination; Voidwalker (Ctrl: Felhunter).", "In combat, Fel Domination; Voidwalker (Ctrl: Felhunter).",
      "Cuando tu demonio muere en pelea.", "When your demon dies mid-fight.",
      rama = { "Demonology" }, extra = { "Summon Felhunter" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/demonology/#macro-demo-fel-dom-summon" } },
    { 18, "FG Searing", "#showtooltip {Searing Pain}\n/petattack [@mouseover,harm,nodead][@target,harm,nodead]\n/cast [@mouseover,harm,nodead][@target,harm,nodead] {Searing Pain}",
      "Manda a tu demonio y Searing Pain (raton u objetivo).", "Sends your demon and Searing Pain (mouseover or target).",
      "Golpe rapido con el demonio.", "Quick hit with your demon.",
      rama = { "Demonology" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/demonology/#macro-demo-brand-peel" } },
    { 12, "FG Funnel", "#showtooltip [mod:ctrl] {Demonic Sacrifice}; {Health Funnel}\n/stopmacro [nomod:ctrl,channeling:Health Funnel]\n/stopcasting\n/cast [mod:ctrl] {Demonic Sacrifice}; {Health Funnel}",
      "Health Funnel; con Ctrl, Demonic Sacrifice.", "Health Funnel; holding Ctrl, Demonic Sacrifice.",
      "Para curar a tu demonio.", "To heal your demon.",
      rama = { "Demonology" }, extra = { "Demonic Sacrifice" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/demonology/#macro-demo-funnel-sacrifice" } },
    { 20, "FG Conflag", "#showtooltip [mod:ctrl] {Conflagrate}; {Shadowburn}\n/stopcasting\n/cast [mod:ctrl,@target,harm,nodead] {Conflagrate}; [@target,harm,nodead] {Shadowburn}",
      "Shadowburn; con Ctrl, Conflagrate.", "Shadowburn; holding Ctrl, Conflagrate.",
      "Tu rafaga para rematar.", "Your burst to finish off.",
      rama = { "Destruction" }, extra = { "Conflagrate" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/destruction/#macro-destro-finisher" } },
    { 1, "FG Havoc", "#showtooltip {Bane of Havoc}\n/cast [@target,harm,nodead] {Bane of Havoc}\n/targetenemy",
      "Bane of Havoc y cambia de objetivo.", "Bane of Havoc and switches target.",
      "Con dos enemigos: dano en los dos.", "With two enemies: damage on both.",
      rama = { "Destruction" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/destruction/#macro-destro-havoc" } },
    { 30, "FG Hellfire", "#showtooltip {Hellfire}\n/stopcasting [nochanneling:Hellfire]\n/cast [nochanneling:Hellfire] {Hellfire}",
      "Hellfire sin cortarlo.", "Hellfire without clipping it.",
      "Grupos de enemigos.", "Groups of enemies.",
      rama = { "Destruction" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/warlock/destruction/#macro-destro-hellfire" } },
  },
  DRUID = {
    { 20, "FG Formas", "#showtooltip\n/cast [swimming] {Aquatic Form}; [outdoors] {Travel Form}; {Cat Form}",
      "Nadando, Aquatic Form; al aire libre, Travel Form; dentro, Cat Form.", "Swimming, Aquatic Form; outdoors, Travel Form; indoors, Cat Form.",
      "Para viajar con un solo boton.", "To travel with one button.",
      extra = { "Travel Form" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/#macro-travel-anywhere" } },
    { 20, "FG Rebirth", "#showtooltip\n/cancelform [@mouseover,help,dead][help,dead]\n/cast [combat,@mouseover,help,dead][combat,help,dead] {Rebirth}; [@mouseover,help,dead][help,dead] {Revive}",
      "Rebirth en combate; Revive fuera (raton u objetivo).", "Rebirth in combat; Revive out of combat (mouseover or target).",
      "Para levantar a un aliado muerto.", "To raise a dead ally.",
      uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/#macro-rebirth-revive" } },
    { 18, "FG Faerie Fire", "#showtooltip\n/cast {Faerie Fire}",
      "Faerie Fire.", "Faerie Fire.",
      "Bajar armadura o revelar sigilo.", "Lower armor or reveal stealth.",
      uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-faerie-fire" } },
    { 8, "FG Roots", "#showtooltip {Entangling Roots}\n/cancelform\n/cast [@mouseover,harm,nodead][harm,nodead] {Entangling Roots}",
      "Sale de forma y Entangling Roots (raton u objetivo).", "Leaves form and Entangling Roots (mouseover or target).",
      "Para inmovilizar a un enemigo.", "To root an enemy.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-entangling-roots-mouseover" } },
    { 18, "FG Hibernate", "#showtooltip\n/cancelform\n/cast [@mouseover,harm,nodead][] {Hibernate}",
      "Sale de forma y Hibernate (raton u objetivo).", "Leaves form and Hibernate (mouseover or target).",
      "Contra bestias o dragonkin.", "Against beasts or dragonkin.",
      uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-hibernate-mouseover" } },
    { 12, "FG Cura propia", "#showtooltip\n/cancelform\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] {Rejuvenation}; [@mouseover,help,nodead][help,nodead][@player] {Regrowth}",
      "Sale de forma y Regrowth; con Ctrl, Rejuvenation (raton, objetivo o ti).", "Leaves form and Regrowth; holding Ctrl, Rejuvenation (mouseover, target or you).",
      "Para curarte y volver a pegar.", "To heal and keep fighting.",
      rama = { "Balance" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/balance/#macro-moonkin-heal" } },
    { 20, "FG Moon+Swarm", "#showtooltip\n/stopcasting\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl,@target,harm,nodead] {Moonfire}; [@mouseover,harm,nodead][@target,harm,nodead] {Insect Swarm}",
      "Insect Swarm; con Ctrl, Moonfire.", "Insect Swarm; holding Ctrl, Moonfire.",
      "Para dejar tus dotes en el enemigo.", "To keep your DoTs up.",
      rama = { "Balance" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/balance/#macro-dots-stopcast" } },
    { 20, "FG Prowl", "#showtooltip {Prowl}\n/dismount\n/cast [noform:3] {Cat Form}\n/cast !{Prowl}",
      "Baja de la montura, Cat Form y Prowl.", "Dismounts, Cat Form and Prowl.",
      "Para entrar en sigilo desde cualquier forma.", "To stealth from any form.",
      rama = { "Feral Combat (Cat)" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-prowl" } },
    { 20, "FG Gato", "#showtooltip\n/cast !{Cat Form}",
      "Cat Form sin salir de ella.", "Cat Form without leaving it.",
      "Para volver a gato y quitarte lentitudes.", "To go back to Cat and remove slows.",
      rama = { "Feral Combat (Cat)" }, uso = "pvp", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-cat-form-forced" } },
    { 24, "FG Shred", "#showtooltip {Shred}\n/cast [mod:ctrl,harm,nodead] Tiger's Fury\n/cast [@target,harm,nodead] {Shred}",
      "Shred; con Ctrl, Tiger's Fury antes.", "Shred; holding Ctrl, Tiger's Fury first.",
      "Tu golpe principal en gato, por la espalda.", "Your main Cat hit, from behind.",
      rama = { "Feral Combat (Cat)" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/feral-combat/#macro-tigers-fury-shred" } },
    { 24, "FG Rake", "#showtooltip\n/startattack\n/cast {Rake}",
      "Empiezas a atacar y Rake.", "Start attacking and Rake.",
      "Sangrado al empezar.", "Bleed at the start.",
      rama = { "Feral Combat (Cat)" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-rake" } },
    { 20, "FG Feral Charge", "#showtooltip\n/cast [@target,harm,nodead] {Feral Charge}\n/cast [@target,harm,nodead] {Bash}",
      "Feral Charge y Bash sobre tu objetivo.", "Feral Charge and Bash on your target.",
      "Para llegar y aturdir.", "To reach and stun.",
      rama = { "Feral Combat (Cat)", "Feral Combat (Bear)" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/feral-combat/#macro-charge-bash" } },
    { 10, "FG Oso", "#showtooltip\n/cast !{Bear Form}",
      "Bear Form sin salir de ella.", "Bear Form without leaving it.",
      "Para tanquear.", "To tank.",
      rama = { "Feral Combat (Bear)" }, uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-bear-form-forced" } },
    { 10, "FG Maul", "#showtooltip\n/startattack\n/cast {Maul}",
      "Empiezas a atacar y Maul.", "Start attacking and Maul.",
      "Con ira de sobra.", "With spare Rage.",
      rama = { "Feral Combat (Bear)" }, uso = "pve", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-maul" } },
    { 10, "FG Maul+Bite", "#showtooltip {Primal Bite}\n/cast [nomod:ctrl,@target,harm,nodead] {Maul}\n/cast [@target,harm,nodead] {Primal Bite}",
      "Maul y Primal Bite.", "Maul and Primal Bite.",
      "Tu golpe principal en oso.", "Your main Bear hit.",
      rama = { "Feral Combat (Bear)" }, extra = { "Primal Bite" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/feral-combat/#macro-mangle-maul" } },
    { 10, "FG Growl", "#showtooltip {Growl}\n/cast [@mouseover,harm,nodead][@target,harm,nodead] {Growl}\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl,harm,nodead] {Challenging Roar}",
      "Growl (raton u objetivo); con Ctrl, Challenging Roar.", "Growl (mouseover or target); holding Ctrl, Challenging Roar.",
      "Para recuperar enemigos.", "To get enemies back.",
      rama = { "Feral Combat (Bear)" }, extra = { "Challenging Roar" }, uso = "pve", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/feral-combat/#macro-growl-mouseover" } },
    { 4, "FG Rejuv", "#showtooltip {Rejuvenation}\n/cancelform\n/cast [@mouseover,help][] {Rejuvenation}",
      "Sale de forma y Rejuvenation (raton u objetivo).", "Leaves form and Rejuvenation (mouseover or target).",
      "Cura constante.", "Steady heal.",
      rama = { "Restoration" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-rejuvenation-mouseover" } },
    { 12, "FG Regrowth", "#showtooltip {Regrowth}\n/cancelform\n/cast [@mouseover,help][] {Regrowth}",
      "Sale de forma y Regrowth (raton u objetivo).", "Leaves form and Regrowth (mouseover or target).",
      "Cura rapida con algo de cura en el tiempo.", "Fast heal with some heal over time.",
      rama = { "Restoration" }, uso = "ambos", fuente = { nombre = "Kami-labs", url = "https://kami-labs.fr/en/macros-wow-forever/#druid-regrowth-mouseover" } },
    { 4, "FG Swiftmend", "#showtooltip [mod:ctrl] {Swiftmend}; {Rejuvenation}\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] {Swiftmend}; [@mouseover,help,nodead][help,nodead][@player] {Rejuvenation}",
      "Rejuvenation; con Ctrl, Swiftmend.", "Rejuvenation; holding Ctrl, Swiftmend.",
      "Cura al instante si ya tiene Rejuvenation.", "Instant heal if Rejuvenation is up.",
      rama = { "Restoration" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/restoration/#macro-rejuv-swiftmend" } },
    { 1, "FG NS+Touch", "#showtooltip [mod:ctrl] {Rebirth}; {Healing Touch}\n/stopcasting\n/cast {Nature's Swiftness}\n/cast [mod:ctrl,@mouseover,help,dead][mod:ctrl,help,dead] {Rebirth}; [nomod:ctrl,@mouseover,help,nodead][nomod:ctrl,help,nodead][nomod:ctrl,@player] {Healing Touch}",
      "Nature's Swiftness y Healing Touch; con Ctrl, Rebirth.", "Nature's Swiftness and Healing Touch; holding Ctrl, Rebirth.",
      "Emergencia: cura grande al momento.", "Emergency: big heal instantly.",
      rama = { "Restoration" }, extra = { "Rebirth" }, uso = "ambos", fuente = { nombre = "Rankedboost", url = "https://rankedboost.com/world-of-warcraft/forever/macros/druid/restoration/#macro-swiftness-heal" } },
  },
}
-- PvE o PvP: cada macro dice su uso (16-oct, campo uso). Consejo "En PvP:" por macro, clave "CLASE|nombre".
-- Cada una dice "En PvP:" cuando se usa distinto contra jugadores; si se usa igual, solo lleva la etiqueta "PvE y PvP".
-- 9-oct (Andy: cero Classic): cada consejo sale de las guias PvP de WoWForeverBuilds de FUENTE_PVP (leidas el 9-oct);
-- fuera lo que no dicen (Overpower contra quien esquiva, cura propia con el Escudo, Garrote en combates largos) y las de
-- Shaman de Classic. Paladin, Hunter y Shaman (Earth Shock): de WoWForeverBuilds (9-oct, auditoria).
local MAC_PVP = {
  -- Arms: "open with Charge or Intercept, apply Hamstring so the target cannot walk away"
  ["WARRIOR|FG Carga"] = { "para llegar a un caster o a quien huye; despues, Hamstring para que no se escape.", "to reach a caster or someone running; then Hamstring so they can't escape." },
  -- Subtlety: "Premeditation -> Cheap Shot -> Kidney Shot: a long stun chain from Stealth"
  ["ROGUE|FG Abrir"] = { "abre con Cheap Shot (aturde) y sigue la cadena de aturdimientos.", "open with Cheap Shot (stun) and keep the stun chain going." },
  -- Combat: "save Kick for Polymorph on your healer or a big spell"; Assassination: "stops healers from casting"
  ["ROGUE|FG Kick"] = { "guardalo para la cura del enemigo, un Polymorph a tu curador o un hechizo grande.", "save it for an enemy heal, a Polymorph on your healer or a big spell." },
  -- Assassination: "delete one and reset with Vanish"; Combat: "save Vanish for a fear"
  ["ROGUE|FG Vanish"] = { "para salir de un Fear o para volver a Stealth y abrir otra vez.", "to get out of a Fear, or to go back into Stealth and open again." },
  -- Discipline: "Power Word: Shield: the first answer to any attack, on yourself or a teammate"
  ["PRIEST|FG Escudo"] = { "es tu primera respuesta a cualquier ataque, sobre ti o un aliado.", "your first answer to any attack, on yourself or a teammate." },
  -- Discipline: "shields, Renew and Penance are your moving heals"; Holy: "use Renew on moving teammates"
  ["PRIEST|FG Renew"] = { "mantenlo puesto mientras corres; te cura sin pararte.", "keep it up while you move; it heals without stopping you." },
  -- Fire: "Fire Blast ... your instant damage while moving"
  ["MAGE|FG Remate"] = { "es tu dano instantaneo mientras te mueves.", "your instant damage while moving." },
  -- Frost: "Slows, Frost Nova, Frostbite freezes and Polymorph keep melee away"
  ["MAGE|FG Nova"] = { "contra melee: congela, alejate y sigue lanzando Frostbolt.", "against melee: freeze, step away and keep casting Frostbolt." },
  -- Frost: "Polymorph the enemy healer at the start of a fight", "open with Polymorph on a second enemy and kill the first"
  ["MAGE|FG Polymorph"] = { "oveja al curador o a uno de dos enemigos; con /focus no pierdes al que atacas.", "sheep the healer or one of two enemies; with /focus you keep your target." },
  -- Destruction: "Life Tap between fights, not during them"
  ["WARLOCK|FG Life Tap"] = { "entre combates, no durante ellos.", "between fights, not during them." },
  -- Affliction: "Fear to break focus", "Fear or Death Coil melee off your healers"; Destruction: "make space to cast"
  ["WARLOCK|FG Miedo"] = { "para quitarte de encima a un melee o salvar a tu curador; te da tiempo para lanzar.", "to get a melee off you or off your healer; it buys time to cast." },
  -- Holy: "stun a healer to set up your team's kill, or a melee who is on you"; Retribution: "stun to start burst or stop a heal"
  ["PALADIN|FG Martillo"] = { "aturde al curador enemigo para que tu equipo lo mate, o para empezar tu rafaga.", "stun the enemy healer to set up your team's kill, or to start your burst." },
  -- Beast Mastery: "Feign Death: drop targets and break some effects; follow with a trap"
  ["HUNTER|FG Fingir"] = { "te quita de objetivo y rompe algunos efectos; despues, pon una trampa.", "drops targets and breaks some effects; follow with a trap." },
  -- Beast Mastery: "Mend Pet with Improved Mend Pet to cleanse your pet"
  ["HUNTER|FG Mascota"] = { "con Improved Mend Pet, Mend Pet tambien limpia a tu mascota.", "with Improved Mend Pet, Mend Pet also cleanses your pet." },
  -- Feral: "Bear Form lets you survive", "Shapeshifting: breaks roots and snares, including Frost Nova and Hamstring"
  -- Enhancement: "Earth Shock their heals"; Elemental: "Earth Shock stops long casts"; Restoration: "Earth Shock: interrupt an enemy healer"
  ["SHAMAN|FG Interrumpir"] = { "guardalo para la cura del enemigo o un lanzamiento largo.", "save it for an enemy heal or a long cast." },
  ["DRUID|FG Oso"] = { "para aguantar; cambiar de forma tambien te quita raices y lentitudes.", "to survive; shifting form also removes roots and slows." },
  -- Feral: "stealth openers in Cat Form", "shifting breaks snares"
  ["DRUID|FG Gato"] = { "para perseguir y hacer dano; cambiar de forma te quita raices y lentitudes.", "to chase and deal damage; shifting form removes roots and slows." },
  -- Feral: "Healing Touch, then back to Cat Form", "Fear and Polymorph in caster form stop you from healing"
  ["DRUID|FG Cura propia"] = { "curate y vuelve enseguida a tu forma: en forma normal te pueden poner Fear o Polymorph.", "heal, then shift straight back: in caster form you can be Feared or Polymorphed." },
}
-- 16-oct: si es PvE, PvP o las dos cosas lo dice cada macro (campo uso, contrastado con su fuente de Forever).
-- 9-oct (regla de Andy: cero datos de Classic): una clase sin guia PvP de Forever va en SIN_PVP_FOREVER (hoy vacia):
-- sus macros quedan sin consejo "En PvP:" y la rotacion PvP muestra el aviso.
local SIN_PVP_FOREVER = {}
local function buscarMacro(clase, nombre)
  for _, m in ipairs(MAC[clase or ""] or {}) do if m[2] == nombre then return m end end
  for _, m in ipairs(MAC.TODAS) do if m[2] == nombre then return m end end
end
-- Acepta la macro (tabla) o su nombre. Devuelve "pve" | "pvp" | "ambos" y el consejo "En PvP:" si lo hay
local function usoMacro(clase, m)
  if type(m) ~= "table" then m = buscarMacro(clase, m) or { [2] = m } end
  local uso = m.uso or "ambos"
  if uso == "pve" or SIN_PVP_FOREVER[clase or ""] then return uso, nil end
  return uso, MAC_PVP[(clase or "") .. "|" .. (m[2] or "")]
end
WowF.usoMacro = usoMacro -- para las pruebas
WowF.datosMacros = function() return MAC, MAC_PVP end -- para las pruebas (16-oct)
WowF.datosRotacion = function() return ROT, NOTA, MAC_PVP end -- para las pruebas (cero Classic, 9-oct)

-- ===================== Utilidades =====================
local function claseJugador() if not UnitClass then return nil end; local _, t = UnitClass("player"); return t end
local function hechizo(clase, nombre) return WowFHechizos and WowFHechizos[clase or ""] and WowFHechizos[clase][nombre] end
local function lotengo(h)
  if not h or not IsPlayerSpell then return false end
  for i = 2, #h do local ok, si = pcall(IsPlayerSpell, h[i]); if ok and si then return true end end
  return false
end
local function idConocido(h)
  if not h then return nil end
  for i = #h, 2, -1 do local ok, si = pcall(IsPlayerSpell or function() end, h[i]); if ok and si then return h[i] end end
  return h[2]
end
local function nombreCliente(id, porDefecto)
  local n
  if id and C_Spell and C_Spell.GetSpellName then local ok, r = pcall(C_Spell.GetSpellName, id); if ok then n = r end end
  if not n and id and GetSpellInfo then local ok, r = pcall(GetSpellInfo, id); if ok then n = r end end
  if type(n) == "string" and n ~= "" then return n end
  return porDefecto
end
local function iconoHechizo(id)
  local t
  -- 12-oct: primero el icono real de WoW Forever (wowF_Iconos.lua: datos de la beta y luego el cliente)
  if id and WowF.iconoHechizo and WowF.iconoHechizo ~= iconoHechizo then local ok, r = pcall(WowF.iconoHechizo, id); if ok then t = r end end
  if not t and id and C_Spell and C_Spell.GetSpellTexture then local ok, r = pcall(C_Spell.GetSpellTexture, id); if ok then t = r end end
  if not t and id and GetSpellTexture then local ok, r = pcall(GetSpellTexture, id); if ok then t = r end end
  return t or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function esTalento(clase, nombre)
  local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[clase or ""]
  return c and c.talentos and c.talentos[nombre] ~= nil
end
-- Nivel en que tu plan coge ese talento (eventos "talento" de WowF.armarPlan: "Nombre (N puntos) · clave" o, si es de
-- un solo punto, "Nombre · clave" / "Nombre")
local function nivelEnPlan(p, nombre)
  for _, e in ipairs(p.eventos or {}) do
    local x = tostring(e[3])
    if e[2] == "talento" and (x == nombre or x:find(nombre .. " (", 1, true) == 1 or x:find(nombre .. " \194\183", 1, true) == 1) then return e[1] end
  end
end
-- Rama con la que subes ahora (si tu plan cambia de rama, la de subir hasta ese nivel)
local function ramaAhora(p)
  local n = UnitLevel("player") or 1
  if p.ramaSubir and p.ramaSubir ~= "" and (p.ramaCambio or 0) > 0 and n < p.ramaCambio then return p.ramaSubir end
  return p.ramaNombre or ""
end
WowF.ramaAhora = ramaAhora

-- Estado de un hechizo para mostrarlo: color, texto, se puede usar ya
local function estado(p, clase, nombre)
  local h = hechizo(clase, nombre)
  local nivel = UnitLevel("player") or 1
  if lotengo(h) then return VERDE, L("lo tienes", "known"), true, h end
  if esTalento(clase, nombre) then
    local n = nivelEnPlan(p, nombre)
    if n then return (n <= nivel and NARANJA or ORO), L("talento: tu plan lo coge a nivel ", "talent: your plan takes it at level ") .. n, false, h end
    return GRIS, L("talento que tu plan no coge", "talent not in your plan"), false, h
  end
  if not h then return GRIS, L("aun no esta en tu clase en Forever", "not available to your class yet"), false, h end
  if (h[1] or 1) > nivel then return ORO, L("a nivel ", "at level ") .. h[1], false, h end
  -- Nivel 1 y no lo tienes: no se entrena (aun no hay informacion de Forever sobre como se aprende)
  if (h[1] or 1) <= 1 then return GRIS, L("aun no hay informacion de Forever sobre como se aprende", "no Forever info yet on how to learn it"), false, h end
  return NARANJA, L("ve a tu entrenador de clase a aprenderlo", "learn it at your class trainer"), false, h
end

-- Hechizos que se aprenden con una mision de clase (guias de Wowhead /forever e Icy Veins /wow-forever, 4-oct-2026)
local function mision(n) return { "se aprende con una mision de clase a nivel " .. n, "learned from a class quest at level " .. n } end
local MISION = {
  ["Defensive Stance"] = mision(10), ["Sunder Armor"] = mision(10), ["Berserker Stance"] = mision(30), ["Intercept"] = mision(30),
  ["Bear Form"] = mision(10), ["Cat Form"] = mision(20),
  ["Tame Beast"] = mision(10), ["Call Pet"] = mision(10),
  ["Summon Imp"] = mision(2), ["Summon Voidwalker"] = mision(10), ["Summon Succubus"] = mision(20), ["Summon Felhunter"] = mision(30),
  -- Icy Veins /wow-forever Elemental: "Water Totems are unlocked through a long Level 20 quest line which also provides Healing Stream Totem"
  ["Healing Stream Totem"] = mision(20),
  -- 9-oct (regla de Andy: cero datos de Classic): Strength of Earth / Searing Totem se entrenan; la mision da el totem
  -- para usarlos (lo explica la NOTA de SHAMAN). No ponerlos aqui sin fuente de Forever que diga que el hechizo sale de la mision.
}
-- Como se aprende un hechizo que te falta: texto corto y que hace el clic ("entrenador", "talentos" o nil)
local function comoAprender(p, clase, nombre)
  local h = hechizo(clase, nombre)
  local nivel = UnitLevel("player") or 1
  if esTalento(clase, nombre) then
    local n = nivelEnPlan(p, nombre)
    return L("es un talento: ponle un punto en la pestana Talentos", "it is a talent: put a point in it in the Talents tab") .. (n and L(" (tu plan lo coge a nivel ", " (your plan takes it at level ") .. n .. ")" or ""), "talentos"
  end
  if h and (h[1] or 1) > nivel then return L("llega a nivel ", "comes at level ") .. h[1] .. L(": entonces ve a tu entrenador de clase", ": then visit your class trainer"), "entrenador" end
  local m = MISION[nombre]
  if m then return L(m[1], m[2]) .. L(": ve a tu entrenador de clase", ": visit your class trainer"), "entrenador" end
  return L("compralo en tu entrenador de clase (el precio te lo dice el entrenador)", "buy it from your class trainer (the trainer tells you the price)"), "entrenador"
end
WowF.comoAprender = comoAprender -- para las pruebas

-- ===================== Fuentes de la rotacion PvE =====================
-- Las mismas guias con las que se audito ROT (4-oct-2026): Wowhead /forever nivel 20 (manda) e Icy Veins /wow-forever nivel 30.
local WH = "https://www.wowhead.com/forever/guide/classes/"
local IV = "https://www.icy-veins.com/wow-forever/"
local FUENTE_PVE = { -- { ruta de Wowhead, slug de Icy Veins o nil }
  WARRIOR = { Arms = { "warrior/arms/level-20-dps-overview", "arms-warrior-melee-dps" }, Fury = { "warrior/fury/level-20-dps-overview", "fury-warrior-melee-dps" },
    Protection = { "warrior/protection/level-20-tank-overview", "protection-warrior-tank" } },
  PALADIN = { Retribution = { "paladin/retribution/level-20-dps-overview", "retribution-paladin-melee-dps" }, Protection = { "paladin/protection/level-20-tank-overview", "protection-paladin-tank" },
    Holy = { "paladin/holy/level-20-healer-overview", "holy-paladin-healer" } },
  HUNTER = { ["Beast Mastery"] = { "hunter/beast-mastery/level-20-dps-overview", "beast-mastery-hunter-ranged-dps" }, Marksmanship = { "hunter/marksmanship/level-20-dps-overview", "marksmanship-hunter-ranged-dps" },
    Survival = { "hunter/survival/level-20-dps-overview", "survival-hunter-melee-dps" } },
  ROGUE = { Combat = { "rogue/combat/level-20-dps-overview", "combat-rogue-melee-dps" }, Assassination = { "rogue/assassination/level-20-dps-overview", "assassination-rogue-melee-dps" },
    Subtlety = { "rogue/subtlety/level-20-dps-overview", "subtlety-rogue-melee-dps" } },
  PRIEST = { Shadow = { "priest/shadow/level-20-dps-overview", "shadow-priest-ranged-dps" }, Discipline = { "priest/discipline/level-20-healer-overview", "discipline-priest-healer" },
    Holy = { "priest/holy/level-20-healer-overview", "holy-priest-healer" } },
  SHAMAN = { Enhancement = { "shaman/enhancement/level-20-dps-overview", "enhancement-shaman-melee-dps" }, Elemental = { "shaman/elemental/level-20-dps-overview", "elemental-shaman-ranged-dps" },
    Restoration = { "shaman/restoration/level-20-healer-overview", "restoration-shaman-healer" } },
  MAGE = { Frost = { "mage/frost/level-20-dps-overview", "frost-mage-ranged-dps" }, Fire = { "mage/fire/level-20-dps-overview", "fire-mage-ranged-dps" },
    Arcane = { "mage/arcane/level-20-dps-overview", "arcane-mage-ranged-dps" } },
  WARLOCK = { Affliction = { "warlock/affliction/level-20-dps-overview", "affliction-warlock-ranged-dps" }, Destruction = { "warlock/destruction/level-20-dps-overview", "destruction-warlock-ranged-dps" },
    Demonology = { "warlock/demonology/level-20-dps-overview", "demonology-warlock-ranged-dps" } },
  DRUID = { ["Feral Combat (Cat)"] = { "druid/feral/level-20-dps-overview", "feral-druid-melee-dps-and-tank" }, ["Feral Combat (Bear)"] = { "druid/feral/level-20-tank-overview", "feral-druid-melee-dps-and-tank" },
    Balance = { "druid/balance/level-20-dps-overview", "balance-druid-ranged-dps" }, Restoration = { "druid/restoration/level-20-healer-overview", "restoration-druid-healer" } },
}
-- Lista de fuentes { nombre, url } de la rotacion PvE de esa rama
local function fuentesPvE(clase, rama)
  local f = FUENTE_PVE[clase or ""] and FUENTE_PVE[clase][rama]
  if not f then return {} end
  local l = { { "Wowhead /forever (" .. L("nivel 20", "level 20") .. ")", WH .. f[1] } }
  if f[2] then table.insert(l, { "Icy Veins /wow-forever (" .. L("nivel 30", "level 30") .. ")", IV .. f[2] .. "-pve-guide" }) end
  return l
end

-- ===================== Rotacion PvP =====================
-- { "Hechizo", "rol", "para que (es)", "why (en)" } en orden de prioridad; rol: control, interrupcion, defensiva, dano, movilidad.
-- Solo hechizos de wowF_Hechizos.lua o talentos de fila <= 5 (llegan antes del nivel 31). Fuentes por clase en FUENTE_PVP.
-- PvP hasta el nivel 30 (5-oct-2026). No hay guias PvP por clase de WoW Forever en Wowhead /forever ni en Icy Veins /wow-forever
-- (Icy Veins: "DPS PvP Tier List COMING SOON"). Cada rama sale de DOS fuentes contrastadas:
--   Warrior, Rogue, Druid, Mage, Warlock, Priest, Paladin, Hunter: guias PvP por rama de WoWForeverBuilds (Forever, nivel 60, "Theorycraft", beta 1.60.1).
--     Solo entra lo que esa guia usa y llega a nivel <= 30. 9-oct (Andy: cero Classic): fuera las guias PvP de Classic (Icy Veins, Wowhead).
--   Shaman: rehecho el 9-oct (noche) con las 3 guias PvP de WoWForeverBuilds (antes salia de Classic y estaba en SIN_PVP_FOREVER).
--   Paladin y Hunter (9-oct, auditoria): rehechos con WoWForeverBuilds (antes salian de Classic); Paladin Protection incluido.
-- Sin guia PvP de Forever (se muestra la rotacion PvE): Druid Feral Combat (Bear) (ninguna guia PvP de oso; solo menciones sueltas).
-- Cada hechizo comprobado contra wowF_Hechizos.lua (nivel <= 30) o talento de fila <= 5 de la rama (wowF_Datos.lua).
-- Fuera por nivel: Mortal Strike, Pummel, Whirlwind, Blind, Pounce, Barkskin, Divine Shield, Viper Sting, Ice Barrier, Death Coil, Howl of Terror...
-- 27-oct: contrastadas las 27 guias PvP de WoWForeverBuilds actualizadas el 24-oct (build 1.60.1.70634). Entran: Arms Berserker Rage + Shield Wall,
--   Fury Berserker Rage, Prot Warrior Hamstring + Intimidating Shout, Subtlety Distract, Feral Primal Bite, Resto Druid Cat Form, Frost Mage
--   Remove Lesser Curse, Destruction Rain of Fire, Demonology Health Funnel, Disc Confounding Flash + Divine Grace, Holy Priest Chastise.
--   Fuera por nivel (>30 o fila >= 6): Adrenaline Rush, Moonkin Form, Innervate, Wild Growth, Prayer of Mending, Soul Fire, Hammer of Wrath,
--   Cleanse, Holy Shield, Riptide, Bestial Wrath, Rage of the Farseer, Winter's Chill (Frost fila 6), Ice Barrier (fila 7).
--   Talentos de otra rama (Piercing Howl en Arms/Prot, Swiftmend en Balance, Voice of Truth en Prot Paladin) no entran.
-- 3-nov (build 1.60.1.70755): fuera Primal Bite (Feral Cat) y Mutilate (Assassination): pasaron a la fila 7 (nivel 40).
-- Formato: { "Hechizo", rol, explicacion es (sin acentos), explicacion en }. FUENTE_PVP[CLASE] = { { nombre, url, ramas } } (ramas nil = todas).
local PVP = {
  WARRIOR = {
    Arms = {
      { "Charge", "movilidad", "Abre con Charge: llegas al objetivo con ira para Hamstring", "Open with Charge to close the gap with Rage ready for Hamstring" },
      { "Hamstring", "control", "Ponlo primero a todo el que pueda huir; asi se queda a tu alcance", "Apply it first on anyone who can run so they stay in melee range" },
      { "Rend", "dano", "Mantenlo en Rogue y Druid: el sangrado no les deja volver al sigilo", "Keep it on Rogues and Druids: the bleed stops them from restealthing" },
      { "Overpower", "dano", "Tras un esquive; no se puede esquivar y atraviesa la Evasion del Rogue", "After a dodge; it cannot be dodged and goes through a Rogue's Evasion" },
      { "Intimidating Shout", "control", "Aleja a los de cuerpo a cuerpo de tu sanador o corta una captura", "Peel melee off your healer or break up a capture" },
      { "Disarm", "defensiva", "En Defensive Stance, desarma al Rogue o Warrior que te esta reventando", "In Defensive Stance, disarm a Rogue or Warrior bursting you" },
      { "Sweeping Strikes", "dano", "Cuando pelean juntos, golpea tambien a un segundo jugador", "In a crowded fight, hit a second player too" },
      { "Intercept", "movilidad", "En Berserker Stance, vuelve a pegarte cuando ya empezo la pelea", "In Berserker Stance, close the gap again once the fight has started" },
      { "Bloodrage", "dano", "Ira al instante para abrir la pelea o cuando te alejan", "Instant Rage to open a fight or when you get kited" },
      { "Berserker Rage", "defensiva", "Guardalo para romper o evitar un Fear (WoWForeverBuilds 24-oct)", "Save it to break or prevent a fear (WoWForeverBuilds Oct 24)" },
      { "Shield Wall", "defensiva", "Cambia a escudo en Defensive Stance y usalo cuando te atacan entre varios", "Swap to a shield in Defensive Stance and use it when you are focused" },
    },
    Fury = {
      { "Charge", "movilidad", "Abre con Charge para llegar al objetivo con ira", "Open with Charge to reach the target with Rage" },
      { "Hamstring", "control", "En cada objetivo que pueda huir; tu trabajo es no soltarlo", "On every target that can run; your job is to stick to them" },
      { "Piercing Howl", "control", "Frena a todos los cercanos; ideal contra el portador de la bandera y su escolta", "Slows everyone nearby; ideal on a flag carrier and their escort" },
      { "Death Wish", "dano", "Cuando vas a matar: mas dano e inmune al miedo, pero recibes mas dano", "When you commit to a kill: more damage and Fear immunity, but you take more damage" },
      { "Intercept", "movilidad", "En Berserker Stance, alcanza al que se escapa a mitad de pelea", "In Berserker Stance, catch whoever breaks free mid-fight" },
      { "Intimidating Shout", "control", "Aparta a los de cuerpo a cuerpo de tu sanador o de la bandera", "Peel melee off your healer or off the flag" },
      { "Disarm", "defensiva", "En Defensive Stance, contra el golpe fuerte de un Rogue o Warrior", "In Defensive Stance, against a Rogue's or Warrior's burst" },
      { "Bloodrage", "dano", "Ira al instante para abrir con Hamstring", "Instant Rage to open with Hamstring" },
      { "Berserker Rage", "defensiva", "Rompe un Fear y te da ira (WoWForeverBuilds 24-oct)", "Breaks fear and gives Rage (WoWForeverBuilds Oct 24)" },
    },
    Protection = {
      { "Shield Bash", "interrupcion", "Corta la cura o la captura; con Improved Shield Bash tambien silencia", "Stop a heal or a capture; with Improved Shield Bash it also silences" },
      { "Concussion Blow", "control", "Aturde 5 s: justo antes de que terminen de capturar", "5 sec stun: right before they finish a capture" },
      { "Charge", "movilidad", "Con Vanguard la usas en Defensive Stance para llegar al atacante", "With Vanguard you use it in Defensive Stance to reach an attacker" },
      { "Disarm", "defensiva", "Desarma al Rogue o Warrior durante su golpe fuerte", "Disarm a Rogue or Warrior during their burst" },
      { "Shield Wall", "defensiva", "Cuando te atacan entre varios y la ayuda aun no llega", "When several enemies focus you and help is not there yet" },
      { "Last Stand", "defensiva", "Vida extra para aguantar en el punto hasta que llegue tu equipo", "Extra health to hold the point until your team arrives" },
      { "Revenge", "dano", "Golpe barato tras bloquear o esquivar; guarda ira para Shield Bash", "Cheap hit after a block or dodge; save Rage for Shield Bash" },
      { "Hamstring", "control", "Tras Charge, para que el atacante no se vaya del punto (WoWForeverBuilds 24-oct)", "After Charge, so attackers cannot leave your point (WoWForeverBuilds Oct 24)" },
      { "Intimidating Shout", "control", "Dispersa al grupo que intenta tomar tu punto", "Scatter a group trying to take your point" },
    },
  },
  ROGUE = {
    Assassination = {
      { "Cheap Shot", "control", "Abre desde Stealth con el aturdimiento", "Open from Stealth with the stun" },
      { "Kidney Shot", "control", "Encadena el segundo aturdimiento", "Chain the second stun" },
      { "Shank", "dano", "Golpe con la mano izquierda que no falla y da 15 de energia (10 s); con Venom tus venenos pegan un 30 % mas 6 s (WoWForeverBuilds 4-nov)", "Off-hand strike that cannot miss and generates 15 Energy (10 sec); with Venom your poisons deal 30% more for 6 sec (WoWForeverBuilds Nov 4)" },
      { "Cold Blood", "dano", "Guardalo para un Eviscerate dentro del Kidney Shot", "Save it for an Eviscerate inside Kidney Shot" },
      { "Eviscerate", "dano", "Remate a 5 puntos para terminar al objetivo", "5-point finisher to end the target" },
      { "Kick", "interrupcion", "Corta una cura cuando el objetivo tiene poca vida", "Interrupt a heal when the target is low" },
      { "Gouge", "control", "Incapacita para vendarte, ponerte detras o volver a Stealth", "Incapacitate to bandage, get behind or restealth" },
      { "Vanish", "defensiva", "Rompe raices y reinicia la pelea; solo uno por pelea", "Breaks roots and resets the fight; only one per fight" },
    },
    Combat = {
      { "Kidney Shot", "control", "Aturde y llega a 5 puntos antes de que se le pase", "Stun, then build to 5 points before it ends" },
      { "Sinister Strike", "dano", "Tu golpe principal para sumar puntos de combo", "Your main combo point builder" },
      { "Eviscerate", "dano", "Remate a 5 puntos", "5-point finisher" },
      { "Shank", "dano", "Golpe con la mano izquierda que no falla y da 15 de energia (10 s): usalo cada vez que este listo (WoWForeverBuilds 4-nov)", "Off-hand strike that cannot miss and generates 15 Energy (10 sec): use it on cooldown (WoWForeverBuilds Nov 4)" },
      { "Kick", "interrupcion", "Con Improved Kick tambien silencia: usalo en la cura grande", "With Improved Kick it also silences: use it on the big heal" },
      { "Gouge", "control", "Corta un hechizo y ponte detras o vendate", "Interrupt a cast, then get behind or bandage" },
      { "Riposte", "control", "Tras parar un golpe: dano y desarma 6 s al de cuerpo a cuerpo", "After a parry: damage and a 6 sec disarm on melee" },
      { "Evasion", "defensiva", "Gana el duelo cuerpo a cuerpo esquivando y parando", "Win melee duels by dodging and parrying" },
      { "Sprint", "movilidad", "Con Improved Sprint quita raices y frenos (Frost Nova, Hamstring)", "With Improved Sprint it removes roots and slows (Frost Nova, Hamstring)" },
      { "Blade Flurry", "dano", "Cuando el sanador esta junto al que golpeas", "When a healer stands next to the player you are hitting" },
    },
    Subtlety = {
      { "Sap", "control", "Saca a un defensor de la pelea antes de empezar", "Take a defender out before the fight begins" },
      { "Premeditation", "dano", "Dos puntos de combo desde Stealth antes de abrir", "Two combo points from Stealth before opening" },
      { "Cheap Shot", "control", "Abre con el aturdimiento largo desde Stealth", "Open with the long stun from Stealth" },
      { "Kidney Shot", "control", "Segundo aturdimiento de la cadena", "Second stun in the chain" },
      { "Hemorrhage", "dano", "Tu golpe principal para puntos de combo en PvP", "Your main PvP combo point builder" },
      { "Ghostly Strike", "defensiva", "Dano y mas esquive contra los de cuerpo a cuerpo", "Damage plus extra dodge against melee" },
      { "Shank", "dano", "Golpe con la mano izquierda que no falla y da 15 de energia (10 s): mas energia para la cadena de aturdimientos (WoWForeverBuilds 4-nov)", "Off-hand strike that cannot miss and generates 15 Energy (10 sec): extra Energy for the stun chain (WoWForeverBuilds Nov 4)" },
      { "Eviscerate", "dano", "Remate tras la cadena de aturdimientos", "Finisher after the stun chain" },
      { "Vanish", "defensiva", "Guardalo contra el miedo de Warlock o Priest, o para reiniciar", "Save it for Warlock or Priest fears, or to reset" },
      { "Preparation", "defensiva", "Solo cuando ya gastaste Vanish y Evasion: te los devuelve", "Only when Vanish and Evasion are both used: resets them" },
      { "Distract", "control", "Voltea a un guardia antes de abrir desde el sigilo (WoWForeverBuilds 24-oct)", "Turn a guard away before you open from Stealth (WoWForeverBuilds Oct 24)" },
    },
  },
  DRUID = {
    ["Feral Combat (Cat)"] = {
      { "Prowl", "movilidad", "Acercate en sigilo y elige tu pelea", "Approach in stealth and pick your fight" },
      { "Rake", "dano", "Abre desde Prowl con el sangrado", "Open from Prowl with the bleed" },
      { "Shred", "dano", "Desde la espalda, tu golpe fuerte para puntos de combo", "From behind, your big combo point builder" },
      { "Rip", "dano", "Sangrado a 5 puntos para rematar", "5-point bleed finisher" },
      { "Feral Charge", "movilidad", "Saltas hasta el enemigo y lo inmovilizas", "Leap to the enemy and root it" },
      { "Bash", "control", "Aturdimiento en Bear Form; Brutal Impact le baja la espera", "Stun in Bear Form; Brutal Impact shortens its cooldown" },
      { "Cat Form", "defensiva", "Cambiar de forma rompe raices y frenos como Frost Nova o Hamstring", "Shapeshifting breaks roots and snares like Frost Nova or Hamstring" },
      { "Travel Form", "movilidad", "Corre mas rapido entre puntos o con la bandera; cambiar de forma quita frenos", "Move faster between points or with the flag; shifting removes snares" },
      { "Healing Touch", "defensiva", "Sal de la forma para curarte tras un mal intercambio", "Drop out of form to heal after a bad trade" },
    },
    Balance = {
      { "Entangling Roots", "control", "Inmoviliza antes de lanzar Starfire", "Root before casting Starfire" },
      { "Moonfire", "dano", "Dano instantaneo mientras te mueves", "Instant damage while moving" },
      { "Insect Swarm", "dano", "Dano en el tiempo mientras huyes", "Damage over time while kiting" },
      { "Starfire", "dano", "Tu golpe mas fuerte; solo con el objetivo controlado", "Your biggest hit; only when the target is controlled" },
      { "Nature's Grasp", "control", "Enraiza al de cuerpo a cuerpo que te pegue", "Roots the melee player who hits you" },
      { "Rejuvenation", "defensiva", "Cura instantanea mientras te mueves", "Instant healing while you move" },
      { "Hibernate", "control", "Duerme a druidas en forma animal y mascotas de cazador", "Sleeps druids in animal form and hunter pets" },
      { "Remove Curse", "defensiva", "Quitate las maldiciones del Warlock y castiga entre sus Fear", "Remove Warlock curses and burst between their Fears" },
    },
    Restoration = {
      { "Rejuvenation", "defensiva", "Mantenla en ti y en aliados; base de tus curas", "Keep it on yourself and allies; the base of your healing" },
      { "Regrowth", "defensiva", "Cura directa mas cura en el tiempo", "Direct heal plus heal over time" },
      { "Swiftmend", "defensiva", "Cura grande instantanea sobre TU Rejuvenation o Regrowth (no la consume)", "Big instant heal on top of YOUR Rejuvenation or Regrowth (does not consume it)" },
      { "Nature's Swiftness", "defensiva", "Seguido de Healing Touch: cura grande instantanea de emergencia", "Followed by Healing Touch: an emergency instant big heal" },
      { "Healing Touch", "defensiva", "Tu cura mas grande; lanzala solo si nadie te puede cortar", "Your biggest heal; cast it only when nobody can interrupt" },
      { "Entangling Roots", "control", "Frena al que te persigue", "Stop a chaser" },
      { "Hibernate", "control", "Duerme al druida en forma de gato u oso", "Sleep a cat or bear druid" },
      { "Travel Form", "movilidad", "Velocidad y quitar frenos; ideal para llevar la bandera", "Speed and snare removal; ideal for flag carrying" },
      { "Bear Form", "defensiva", "Aguanta cuando te atacan los de cuerpo a cuerpo", "Survive when melee focus you" },
      { "Cat Form", "movilidad", "Velocidad y quitarte frenos; cambiar de forma rompe raices (WoWForeverBuilds 24-oct)", "Speed and snare removal; shapeshifting breaks roots (WoWForeverBuilds Oct 24)" },
    },
  },
  MAGE = {
    Frost = {
      { "Frost Nova", "control", "Congela al cuerpo a cuerpo en el sitio; alejate y castiga", "Roots melee in place; step away and punish" },
      { "Frostbolt", "dano", "Dano principal y frena al objetivo para que no te alcance", "Main damage and slows the target so it cannot reach you" },
      { "Ice Lance", "dano", "Instantaneo y fuerte contra objetivo congelado (Frost Nova, Frostbite); comparte 8 s de reutilizacion con Fire Blast", "Instant and strong against frozen targets (Frost Nova, Frostbite); shares an 8 sec cooldown with Fire Blast" },
      { "Polymorph", "control", "Saca a un enemigo de la pelea o te deja recuperarte y beber", "Takes one enemy out of the fight or lets you recover" },
      { "Counterspell", "interrupcion", "Corta la curacion o el control del lanzador enemigo", "Cuts the enemy caster's heal or crowd control" },
      { "Blink", "movilidad", "Rompe aturdimientos y raices; no lo gastes al principio", "Breaks stuns and roots; do not waste it early" },
      { "Ice Block", "defensiva", "Inmune unos segundos cuando vas a morir", "Immune for a few seconds when you are about to die" },
      { "Cone of Cold", "control", "Frena a todos los que tienes delante cuando se acercan", "Slows everyone in front of you when they close in" },
      { "Cold Snap", "defensiva", "Reinicia Frost Nova e Ice Block para un segundo uso", "Resets Frost Nova and Ice Block for a second use" },
      { "Remove Lesser Curse", "defensiva", "Quitate a ti y a tus aliados las maldiciones del Warlock (WoWForeverBuilds 24-oct)", "Remove Warlock curses from yourself and allies (WoWForeverBuilds Oct 24)" },
    },
    Fire = {
      { "Polymorph", "control", "Convierte en oveja y abre con Pyroblast desde lejos", "Sheep the target and open with Pyroblast from range" },
      { "Pyroblast", "dano", "Golpe de apertura a distancia maxima o tras Polymorph", "Opening nuke at max range or after Polymorph" },
      { "Fire Blast", "dano", "Dano instantaneo para rematar o mientras corres", "Instant damage to finish or while moving" },
      { "Frost Nova", "control", "Congela al cuerpo a cuerpo y sigue con Fire Blast", "Roots melee, then follow with Fire Blast" },
      { "Blast Wave", "control", "Dano en area y frena a quien se te pega", "Area damage that slows whoever is on you" },
      { "Counterspell", "interrupcion", "Corta la curacion del enemigo", "Interrupts the enemy heal" },
      { "Blink", "movilidad", "Sal de aturdimientos y raices", "Escape stuns and roots" },
      { "Ice Block", "defensiva", "Ultimo recurso para no morir", "Last resort to avoid dying" },
      { "Scorch", "dano", "Hechizo de fuego rapido para no quedarte quieto mucho rato", "Fast fire cast so you do not stand still long" },
    },
    Arcane = {
      { "Polymorph", "control", "Controla a un enemigo; con Presence of Mind sale instantaneo", "Controls one enemy; instant with Presence of Mind" },
      { "Counterspell", "interrupcion", "Corta al sanador o al lanzador enemigo", "Cuts the healer or enemy caster" },
      { "Presence of Mind", "dano", "Tu siguiente hechizo sale instantaneo: Polymorph o golpe fuerte", "Next spell is instant: Polymorph or a big hit" },
      -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L207): cada carga de Arcane Blast suma poder con hechizos (15 % del Intelecto) y sube el costo, hasta 4, 15 s
      { "Arcane Blast", "dano", "Golpe principal; cada carga suma poder con hechizos y sube el costo (hasta 4, 18 s)", "Main nuke; each stack adds spell power and raises the cost (up to 4, 18 sec)" },
      { "Frostbolt", "dano", "Frena al objetivo entre cargas de Arcane Blast", "Slows the target between Arcane Blast stacks" },
      { "Arcane Explosion", "control", "Saca de sigilo a Rogue y Druid cercanos", "Reveals nearby stealthed Rogues and Druids" },
      { "Frost Nova", "control", "Congela al cuerpo a cuerpo para escapar", "Roots melee so you can escape" },
      { "Blink", "movilidad", "Rompe aturdimientos y raices", "Breaks stuns and roots" },
      { "Ice Block", "defensiva", "Inmune cuando la vida esta muy baja", "Immune when health is very low" },
    },
  },
  WARLOCK = {
    Affliction = {
      { "Corruption", "dano", "Instantaneo; ponlo primero y sigue moviendote", "Instant; apply it first and keep moving" },
      { "Bane of Agony", "dano", "Dano constante instantaneo que no se rompe con Fear", "Instant steady damage that keeps ticking through Fear" },
      { "Siphon Life", "dano", "Dano y curacion instantaneos a la vez", "Instant damage and self-heal at once" },
      { "Curse of Exhaustion", "control", "Frena al cuerpo a cuerpo; no sirve contra Druid que cambia de forma", "Slows melee; useless against shapeshifting Druids" },
      { "Fear", "control", "Tu control principal; tus danos siguen mientras huye", "Your main control; your DoTs keep ticking while it runs" },
      { "Drain Life", "dano", "Te curas mientras dana; con Fel Concentration casi no te cortan", "Heals you while dealing damage; Fel Concentration resists pushback" },
      { "Summon Felhunter", "interrupcion", "La mascota contra lanzadores: corta y quita magia", "Pet against casters: interrupts and removes magic" },
    },
    Destruction = {
      { "Fear", "control", "Controla al enemigo para lanzar sin que te corten", "Controls the enemy so you can cast safely" },
      { "Immolate", "dano", "Abre con el y prepara Conflagrate", "Open with it to set up Conflagrate" },
      { "Conflagrate", "dano", "Golpe instantaneo fuerte tras Immolate", "Strong instant hit after Immolate" },
      { "Searing Pain", "dano", "Mas rapido que Shadow Bolt y de otra escuela que Fear", "Faster than Shadow Bolt and a different school than Fear" },
      { "Shadowburn", "dano", "Instantaneo para rematar al enemigo herido", "Instant finisher on a wounded enemy" },
      { "Hellfire", "dano", "Dano en area cuando te rodean en un campo de batalla", "Area damage when surrounded in a battleground" },
      { "Rain of Fire", "dano", "Dano en area sobre un punto lleno de enemigos; con Pyroclasm puede aturdir (WoWForeverBuilds 24-oct)", "Area damage on a crowded point; with Pyroclasm it can stun (WoWForeverBuilds Oct 24)" },
      { "Summon Felhunter", "interrupcion", "Spell Lock contra lanzadores; contra cuerpo a cuerpo usa Succubus (Seduction)", "Spell Lock against casters; use the Succubus (Seduction) against melee" },
    },
    Demonology = {
      { "Summon Felhunter", "interrupcion", "Tu mascota de PvP contra lanzadores y sanadores", "Your PvP pet against casters and healers" },
      { "Summon Voidwalker", "defensiva", "Mejor mascota contra cuerpo a cuerpo como Warrior o Rogue", "Better pet against melee like Warriors or Rogues" },
      { "Soul Link", "defensiva", "Tu mascota recibe parte del dano que te hacen", "Your pet takes part of the damage you receive" },
      { "Fel Domination", "defensiva", "Invoca otra mascota al instante si te matan la tuya", "Instantly summon a new pet if yours dies" },
      { "Corruption", "dano", "Dano instantaneo que aplicas sin quedarte quieto", "Instant damage applied without standing still" },
      { "Bane of Agony", "dano", "Dano constante instantaneo", "Instant steady damage" },
      { "Fear", "control", "Controla al enemigo mientras tus danos siguen", "Controls the enemy while your DoTs tick" },
      { "Curse of Exhaustion", "control", "Frena al cuerpo a cuerpo para mantener distancia", "Slows melee so you keep your distance" },
      { "Health Funnel", "defensiva", "Mantiene vivo al demonio de Soul Link (WoWForeverBuilds 24-oct)", "Keeps your Soul Link demon alive (WoWForeverBuilds Oct 24)" },
    },
  },
  PRIEST = {
    Shadow = {
      { "Power Word: Shield", "defensiva", "El mejor escudo contra cuerpo a cuerpo; ponlo antes de que abra el Rogue", "Best anti-melee tool; cast it before the Rogue opener" },
      { "Shadow Word: Pain", "dano", "Dano instantaneo; ponlo y sigue moviendote", "Instant damage; apply it and keep moving" },
      -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L123/133): Devouring Plague CD 24 s (antes 1 min); Vampiric Embrace CD 30 s (antes 1 min) y no se resiste
      { "Devouring Plague", "dano", "Dano constante fuerte; con Vampiric Embrace te cura (se recarga en 24 s)", "Strong DoT; heals you with Vampiric Embrace (24 sec cooldown)" },
      { "Psychic Scream", "control", "Espanta a los que tienes encima", "Fears everyone on top of you" },
      { "Mind Blast", "dano", "Golpe fuerte; lanzalo solo cuando el enemigo no te alcance", "Big hit; cast it only when the enemy cannot reach you" },
      { "Mind Flay", "dano", "Frena al cuerpo a cuerpo cuando vuelve del Psychic Scream", "Slows melee walking back after Psychic Scream" },
      { "Silence", "interrupcion", "Silencia 5 segundos al sanador o lanzador enemigo", "Silences the enemy healer or caster for 5 seconds" },
      { "Vampiric Embrace", "defensiva", "Te curas con el dano que haces (se recarga en 30 s y no se resiste)", "Heals you from the damage you deal (30 sec cooldown, can't be resisted)" },
      { "Mana Burn", "dano", "Deja sin mana a Druid, Shaman y Paladin", "Drains mana from Druids, Shamans and Paladins" },
    },
    Discipline = {
      { "Power Word: Shield", "defensiva", "Escudo que evita que te corten al lanzar", "Shield that prevents spell pushback" },
      { "Penance", "dano", "Cura o dana en rafaga, segun el objetivo", "Burst heal or damage, depending on target" },
      { "Psychic Scream", "control", "Espanta al cuerpo a cuerpo que te persigue", "Fears melee chasing you" },
      { "Dispel Magic", "defensiva", "Quita Polymorph o Fear a un aliado, o un beneficio al enemigo", "Removes Polymorph or Fear from an ally, or a buff from an enemy" },
      { "Flash Heal", "defensiva", "Curacion rapida cuando te presionan", "Fast heal under pressure" },
      { "Mana Burn", "dano", "Quema el mana del sanador enemigo", "Burns the enemy healer's mana" },
      { "Inner Focus", "defensiva", "Tu siguiente hechizo no cuesta mana", "Your next spell costs no mana" },
      { "Confounding Flash", "control", "Hechizo de entrenador de WoW Forever: confunde a los enemigos cercanos (WoWForeverBuilds 24-oct)", "WoW Forever trainer spell: confuses nearby enemies (WoWForeverBuilds Oct 24)" },
      { "Divine Grace", "defensiva", "Hechizo de entrenador de WoW Forever: cura al instante a un objetivo con menos de la mitad de vida", "WoW Forever trainer spell: instant heal on a target below half health" },
    },
    Holy = {
      { "Power Word: Shield", "defensiva", "Escudo en ti o en el aliado atacado", "Shield yourself or the ally under attack" },
      { "Flash Heal", "defensiva", "Curacion rapida principal en campos de batalla; con Holy Binding, al curar a un aliado tu tambien recibes el 50 %", "Main fast heal in battlegrounds; with Holy Binding, healing an ally also heals you for 50%" },
      { "Renew", "defensiva", "Curacion instantanea mientras te mueves", "Instant heal while moving" },
      { "Psychic Scream", "control", "Espanta a quien te persigue", "Fears whoever is chasing you" },
      { "Dispel Magic", "defensiva", "Quita Polymorph y Fear a tus aliados", "Removes Polymorph and Fear from allies" },
      { "Holy Nova", "control", "Saca de sigilo a Rogue y Druid y cura al grupo", "Reveals stealthed Rogues and Druids and heals the group" },
      { "Chastise", "control", "Hechizo de entrenador de WoW Forever: inmoviliza un rato a un humanoide (los jugadores cuentan) (WoWForeverBuilds 24-oct)", "WoW Forever trainer spell: briefly immobilizes a Humanoid (players count) (WoWForeverBuilds Oct 24)" },
    },
  },
  PALADIN = {
    -- WoWForeverBuilds retribution-paladin-pvp-guide (17-sep): HoJ "stun to start burst or stop a heal"; Repentance "take a humanoid
    -- healer or second attacker out of the fight; damage breaks it"; "Seal of Command and Judgement"; Sacred Arbiter "Holy Strike refreshes
    -- Judgement effects"; BoF "against roots and slows on yourself or your carrier". Fuera por nivel: Hammer of Wrath (44), Divine Shield (34),
    -- Cleanse (42); Twist of Light es fila 7. Judgement de Seal of Command: "97 if the target is stunned or incapacitated" (talentos de la build).
    Retribution = {
      { "Hammer of Justice", "control", "Aturde para empezar tu rafaga o para cortar una cura", "Stun to start your burst or to stop a heal" },
      { "Repentance", "control", "Saca de la pelea a un curador humanoide o a un segundo atacante; el dano lo despierta", "Take a humanoid healer or a second attacker out of the fight; damage breaks it" },
      { "Seal of Command", "dano", "Tu sello: golpes fuertes con arma de dos manos", "Your seal: big two-hander procs" },
      { "Judgement", "dano", "Con Seal of Command hace el doble de dano si el objetivo esta aturdido: usalo tras Hammer of Justice", "With Seal of Command it deals double damage on a stunned target: use it after Hammer of Justice" },
      { "Holy Strike", "dano", "Con Sacred Arbiter renueva tus efectos de Judgement en el objetivo", "With Sacred Arbiter it refreshes your Judgement effects on the target" },
      { "Blessing of Freedom", "movilidad", "Contra raices y lentitudes, sobre ti o sobre quien lleva la bandera", "Against roots and slows, on yourself or your flag carrier" },
    },
    -- WoWForeverBuilds protection-paladin-pvp-guide (17-sep): HoJ "stop a capture or a flag carrier"; Templar's Bulwark "use when three
    -- attackers commit to you; Forbearance follows"; BoF "on your carrier or on yourself against roots"; Flash of Light / Holy Light "between stuns".
    -- Fuera por nivel: Holy Shield (40), Iron Creed (fila 6, 35), Cleanse (42).
    Protection = {
      { "Hammer of Justice", "control", "Para cortar una captura o frenar a quien lleva la bandera", "Stop a capture or a flag carrier" },
      { "Templar's Bulwark", "defensiva", "Cuando tres atacantes van por ti; despues te queda Forbearance", "When three attackers commit to you; Forbearance follows" },
      { "Blessing of Freedom", "movilidad", "Sobre quien lleva la bandera o sobre ti contra raices", "On your flag carrier or on yourself against roots" },
      { "Holy Strike", "dano", "Tu golpe cuerpo a cuerpo mientras defiendes", "Your melee strike while you defend" },
      { "Flash of Light", "defensiva", "Curate entre aturdimientos", "Heal between stuns" },
      { "Holy Light", "defensiva", "Cura grande entre aturdimientos", "Big heal between stuns" },
    },
    -- WoWForeverBuilds holy-paladin-pvp-guide (17-sep): HoJ "stun a healer to set up your team's kill, or a melee who is on you";
    -- BoF "free a rooted Warrior or a slowed flag carrier"; BoP "save a teammate from physical burst; remember it applies Forbearance";
    -- Voice of Truth "before a silence or interrupt is coming"; Holy Shock "an instant heal or damage spell while moving or under interrupts";
    -- Divine Favor "a guaranteed crit heal to save a teammate". Fuera por nivel: Divine Shield (34), Cleanse (42), Light's Vigil (fila 7).
    Holy = {
      { "Hammer of Justice", "control", "Aturde al curador enemigo para que tu equipo lo mate, o al melee que va por ti", "Stun a healer to set up your team's kill, or a melee who is on you" },
      { "Blessing of Freedom", "movilidad", "Libera a un Warrior enraizado o a quien lleva la bandera y va lento", "Free a rooted Warrior or a slowed flag carrier" },
      { "Blessing of Protection", "defensiva", "Salva a un aliado de una rafaga fisica; recuerda que pone Forbearance", "Save a teammate from physical burst; remember it applies Forbearance" },
      { "Voice of Truth", "defensiva", "Usalo antes de que llegue un silencio o una interrupcion", "Use it before a silence or interrupt is coming" },
      { "Holy Shock", "defensiva", "Cura o dano al instante mientras te mueves o te interrumpen", "Instant heal or damage while moving or under interrupts" },
      { "Divine Favor", "defensiva", "Una cura con critico seguro para salvar a un aliado", "A guaranteed crit heal to save a teammate" },
    },
  },
  HUNTER = {
    -- WoWForeverBuilds beast-mastery-hunter-pvp-guide (17-sep): Intimidation "stun a healer or a Warrior on your team's healer";
    -- Concussive Shot "keep melee slowed, with a chance to stun"; "Freezing Trap and Frost Trap: control melee that reach you";
    -- Feign Death "drop targets and break some effects; follow with a trap"; "Mend Pet with Improved Mend Pet to cleanse your pet".
    -- Fuera por nivel: Bestial Wrath (40), Viper Sting (36).
    ["Beast Mastery"] = {
      { "Intimidation", "control", "Aturde al curador enemigo o al Warrior que va por tu curador", "Stun a healer, or a Warrior on your team's healer" },
      { "Concussive Shot", "control", "Mantiene lento al melee, con probabilidad de aturdir", "Keep melee slowed, with a chance to stun" },
      { "Freezing Trap", "control", "Controla al melee que te alcanza", "Control melee that reach you" },
      { "Frost Trap", "control", "Controla al melee que te alcanza", "Control melee that reach you" },
      { "Feign Death", "defensiva", "Te quita de objetivo y rompe algunos efectos; despues, una trampa", "Drop targets and break some effects; follow with a trap" },
      { "Mend Pet", "defensiva", "Con Improved Mend Pet limpia a tu mascota", "With Improved Mend Pet it cleanses your pet" },
    },
    -- WoWForeverBuilds marksmanship-hunter-pvp-guide (17-sep): Scatter Shot "peel a melee, then trap or step back into range";
    -- Concussive Shot "your main slow; Improved Concussive Shot adds a stun chance"; "Aimed Shot and Multi-Shot: burst on low-armor targets";
    -- "Frost Trap with Entrapment: area roots on flags and chokes"; "Feign Death: drop targets, then Freezing Trap a melee";
    -- Deterrence "survive a melee burst window". Parche 8-oct: Entrapment solo en la activacion inicial de Frost Trap. Fuera: Viper Sting (36).
    Marksmanship = {
      { "Scatter Shot", "control", "Quitate de encima a un melee; despues trampa o vuelve a distancia", "Peel a melee, then trap or step back into range" },
      { "Concussive Shot", "control", "Tu lentitud principal; Improved Concussive Shot le da probabilidad de aturdir", "Your main slow; Improved Concussive Shot adds a stun chance" },
      { "Aimed Shot", "dano", "Rafaga contra objetivos con poca armadura", "Burst on low-armor targets" },
      { "Multi-Shot", "dano", "Rafaga contra objetivos con poca armadura", "Burst on low-armor targets" },
      { "Frost Trap", "control", "Con Entrapment enraiza en banderas y pasillos (desde el parche del 8-oct, solo al activarse)", "With Entrapment it roots on flags and chokes (since the Oct 8 patch, only when it triggers)" },
      { "Feign Death", "defensiva", "Te quita de objetivo; despues, Freezing Trap a un melee", "Drop targets, then Freezing Trap a melee" },
      { "Deterrence", "defensiva", "Aguanta la rafaga de un melee", "Survive a melee burst window" },
    },
    -- WoWForeverBuilds survival-hunter-pvp-guide (17-sep): Wing Clip "slow and possibly root a melee next to you, then step back";
    -- Deterrence "when melee burst starts"; Counterattack "root after a parry to escape"; "Frost Trap: on flags and chokes, rooting with
    -- Entrapment"; "Freezing Trap: after Feign Death on a melee"; Scatter Shot "peel a second attacker"; contra Warrior "Wing Clip, step away,
    -- Concussive Shot". Parche 8-oct: Improved Wing Clip con menos probabilidad en rangos bajos. Fuera: Viper Sting (36).
    Survival = {
      { "Wing Clip", "control", "Ralentiza y puede enraizar al melee pegado a ti; despues alejate", "Slow and possibly root a melee next to you, then step back" },
      { "Deterrence", "defensiva", "Cuando empieza la rafaga de un melee", "When melee burst starts" },
      { "Counterattack", "control", "Tras parar un golpe, enraiza para escapar", "Root after a parry to escape" },
      { "Frost Trap", "control", "En banderas y pasillos; enraiza con Entrapment (desde el parche del 8-oct, solo al activarse)", "On flags and chokes, rooting with Entrapment (since the Oct 8 patch, only when it triggers)" },
      { "Feign Death", "defensiva", "Te quita de objetivo; despues, Freezing Trap", "Drop targets, then Freezing Trap" },
      { "Freezing Trap", "control", "Despues de Feign Death, sobre un melee", "After Feign Death, on a melee" },
      { "Scatter Shot", "control", "Quitate de encima a un segundo atacante", "Peel a second attacker" },
      { "Concussive Shot", "control", "Contra un Warrior: Wing Clip, alejate y Concussive Shot", "Against a Warrior: Wing Clip, step away, Concussive Shot" },
    },
  },
  SHAMAN = {
    -- WoWForeverBuilds enhancement-shaman-pvp-guide (17-sep): "A Windfury proc followed by Stormstrike and Earth Shock can end a fight
    -- in seconds"; "Earth Shock their heals"; Frost Shock "slow runners and flag carriers"; Purge "remove shields, Blessing of Protection
    -- and other buffs"; Grounding Totem "absorb a Polymorph, Fear or big spell"; "Stay on a target with Frost Shock slows and Earthbind
    -- Totem"; contra Hunter "root their pet with Earthbind"; "use Ghost Wolf to reach the fight". Fuera por nivel: Rage of the Farseer (fila 7), Maelstrom.
    Enhancement = {
      { "Stormstrike", "dano", "Stormstrike y enseguida Earth Shock: esa rafaga puede acabar la pelea en segundos", "Stormstrike, then Earth Shock right away: that burst can end a fight in seconds" },
      { "Earth Shock", "interrupcion", "Interrumpe, sobre todo las curas del enemigo", "Interrupts, above all enemy heals" },
      { "Frost Shock", "control", "Frena a quien huye y a quien lleva la bandera", "Slow runners and flag carriers" },
      { "Purge", "control", "Quita escudos, Blessing of Protection y otros efectos; contra Priest, Power Word: Shield y luego rafaga", "Remove shields, Blessing of Protection and other buffs; against Priests, Power Word: Shield, then burst" },
      { "Grounding Totem", "defensiva", "Absorbe un Polymorph, un Fear o un hechizo grande", "Absorb a Polymorph, Fear or big spell" },
      { "Earthbind Totem", "control", "Para seguir pegado al objetivo; contra Hunter, sobre su mascota", "To stay on your target; against Hunters, on their pet" },
      { "Ghost Wolf", "movilidad", "Para llegar a la pelea; sin el, Hunter y Frost Mage te mantienen lejos", "To reach the fight; without it, Hunters and Frost Mages keep you away" },
    },
    -- WoWForeverBuilds elemental-shaman-pvp-guide (17-sep): "Earthbind Totem with Earthbound: root melee, then cast freely"; "Once a target
    -- is rooted, Flame Shock into Lava Burst and Lightning Bolt land without interruption from melee"; "Earth Shock: interrupts a cast;
    -- Reverberation brings it back sooner"; Grounding "absorbs an incoming spell such as Polymorph or Fear"; "Tremor Totem breaks the next one";
    -- "Purge Power Word: Shield"; "keep Ghost Wolf to escape". Fuera por nivel: Chain Lightning (32).
    -- Parche 15-oct (build 1.60.1.70425, foreverchanges.pro/patch-notes, notas-70425 L182/184): Lava Burst rango 1 a nivel 30 (antes 40), talento de medalla de oro de 21 puntos en la fila 5, sin prerrequisito: entra
    -- 3-nov: Blizzard elimina Lava Burst al lanzamiento (post del 3-nov, us.forums.blizzard.com/en/wow/t/2360696/9): sale del consejo PvP
    Elemental = {
      { "Earthbind Totem", "control", "Con Earthbound enraiza al melee; despues lanza tranquilo", "With Earthbound it roots melee; then cast freely" },
      { "Flame Shock", "dano", "Abre tu rafaga en cuanto el objetivo esta enraizado", "Opens your burst once the target is rooted" },
      { "Lightning Bolt", "dano", "Con el objetivo enraizado, el melee no te lo interrumpe", "With the target rooted, melee can't interrupt it" },
      { "Earth Shock", "interrupcion", "Interrumpe un lanzamiento; Reverberation lo trae antes", "Interrupts a cast; Reverberation brings it back sooner" },
      { "Grounding Totem", "defensiva", "Absorbe un Polymorph o un Fear que viene hacia ti", "Absorbs an incoming spell such as Polymorph or Fear" },
      { "Tremor Totem", "defensiva", "Contra Warlock: rompe el siguiente Fear", "Against Warlocks: breaks the next Fear" },
      { "Purge", "control", "Quita escudos y bendiciones; contra Priest, Power Word: Shield antes de tu rafaga", "Remove shields and blessings; against Priests, Power Word: Shield before your burst" },
      { "Ghost Wolf", "movilidad", "Para escapar de Warrior y Rogue y moverte entre peleas", "To escape Warriors and Rogues and move between fights" },
    },
    -- WoWForeverBuilds restoration-shaman-pvp-guide (17-sep): "Nature's Swiftness + Healing Wave: an instant large heal"; "save Nature's
    -- Swiftness for yourself"; "Tremor Totem: break fear effects on your group"; "Grounding Totem: absorb Polymorph, Fear or a big spell";
    -- "Earthbind Totem against melee"; "Earth Shock: interrupt an enemy healer"; "Purge: remove enemy shields and buffs"; "Ghost Wolf to escape".
    -- Fuera por nivel: Riptide (40); Water Shield no esta en la build.
    Restoration = {
      { "Nature's Swiftness", "defensiva", "Con Healing Wave: cura grande instantanea; guardala para quien va a morir (o para ti contra melee)", "With Healing Wave: an instant large heal; save it for someone about to die (or yourself against melee)" },
      { "Healing Wave", "defensiva", "Tu cura grande; con Nature's Swiftness sale al instante", "Your big heal; instant with Nature's Swiftness" },
      { "Tremor Totem", "defensiva", "Rompe los miedos de tu grupo", "Break fear effects on your group" },
      { "Grounding Totem", "defensiva", "Absorbe un Polymorph, un Fear o un hechizo grande", "Absorb a Polymorph, Fear or big spell" },
      { "Earthbind Totem", "control", "Contra los de cuerpo a cuerpo", "Against melee" },
      { "Earth Shock", "interrupcion", "Interrumpe al curador enemigo", "Interrupt an enemy healer" },
      { "Purge", "control", "Quita escudos y efectos beneficiosos al enemigo", "Remove enemy shields and buffs" },
      { "Ghost Wolf", "movilidad", "Para escapar de los de cuerpo a cuerpo", "To escape melee" },
    },
  },
}

local WFB = "https://wowforeverbuilds.com/guide/"
local IVF = "https://www.icy-veins.com/wow-forever/"
local FUENTE_PVP = {
  WARRIOR = {
    { "WoWForeverBuilds: Arms Warrior PvP", WFB .. "arms-warrior-pvp-guide", { Arms = true } },
    { "WoWForeverBuilds: Fury Warrior PvP", WFB .. "fury-warrior-pvp-guide", { Fury = true } },
    { "WoWForeverBuilds: Protection Warrior PvP", WFB .. "protection-warrior-pvp-guide", { Protection = true } },
  },
  ROGUE = {
    { "WoWForeverBuilds: Assassination Rogue PvP", WFB .. "assassination-rogue-pvp-guide", { Assassination = true } },
    { "WoWForeverBuilds: Combat Rogue PvP", WFB .. "combat-rogue-pvp-guide", { Combat = true } },
    { "WoWForeverBuilds: Subtlety Rogue PvP", WFB .. "subtlety-rogue-pvp-guide", { Subtlety = true } },
  },
  DRUID = {
    { "WoWForeverBuilds: Feral Druid PvP", WFB .. "feral-combat-druid-pvp-guide", { ["Feral Combat (Cat)"] = true } },
    { "WoWForeverBuilds: Balance Druid PvP", WFB .. "balance-druid-pvp-guide", { Balance = true } },
    { "WoWForeverBuilds: Restoration Druid PvP", WFB .. "restoration-druid-pvp-guide", { Restoration = true } },
  },
  MAGE = {
    { "WoWForeverBuilds: Frost Mage PvP", WFB .. "frost-mage-pvp-guide", { Frost = true } },
    { "WoWForeverBuilds: Fire Mage PvP", WFB .. "fire-mage-pvp-guide", { Fire = true } },
    { "WoWForeverBuilds: Arcane Mage PvP", WFB .. "arcane-mage-pvp-guide", { Arcane = true } },
  },
  WARLOCK = {
    { "WoWForeverBuilds: Affliction Warlock PvP", WFB .. "affliction-warlock-pvp-guide", { Affliction = true } },
    { "WoWForeverBuilds: Destruction Warlock PvP", WFB .. "destruction-warlock-pvp-guide", { Destruction = true } },
    { "WoWForeverBuilds: Demonology Warlock PvP", WFB .. "demonology-warlock-pvp-guide", { Demonology = true } },
  },
  PRIEST = {
    { "WoWForeverBuilds: Shadow Priest PvP", WFB .. "shadow-priest-pvp-guide", { Shadow = true } },
    { "WoWForeverBuilds: Discipline Priest PvP", WFB .. "discipline-priest-pvp-guide", { Discipline = true } },
    { "WoWForeverBuilds: Holy Priest PvP", WFB .. "holy-priest-pvp-guide", { Holy = true } },
  },
  PALADIN = {
    { "WoWForeverBuilds: Retribution Paladin PvP", WFB .. "retribution-paladin-pvp-guide", { Retribution = true } },
    { "WoWForeverBuilds: Protection Paladin PvP", WFB .. "protection-paladin-pvp-guide", { Protection = true } },
    { "WoWForeverBuilds: Holy Paladin PvP", WFB .. "holy-paladin-pvp-guide", { Holy = true } },
  },
  HUNTER = {
    { "WoWForeverBuilds: Beast Mastery Hunter PvP", WFB .. "beast-mastery-hunter-pvp-guide", { ["Beast Mastery"] = true } },
    { "WoWForeverBuilds: Marksmanship Hunter PvP", WFB .. "marksmanship-hunter-pvp-guide", { Marksmanship = true } },
    { "WoWForeverBuilds: Survival Hunter PvP", WFB .. "survival-hunter-pvp-guide", { Survival = true } },
  },
  SHAMAN = {
    { "WoWForeverBuilds: Enhancement Shaman PvP", WFB .. "enhancement-shaman-pvp-guide", { Enhancement = true } },
    { "WoWForeverBuilds: Elemental Shaman PvP", WFB .. "elemental-shaman-pvp-guide", { Elemental = true } },
    { "WoWForeverBuilds: Restoration Shaman PvP", WFB .. "restoration-shaman-pvp-guide", { Restoration = true } },
  },
}
-- Fuentes que valen para tu rama (las que no dicen rama valen para todas)
local function fuentesPvP(clase, rama)
  local l = {}
  for _, f in ipairs(FUENTE_PVP[clase or ""] or {}) do
    if not f[3] or f[3][rama] then table.insert(l, f) end
  end
  return l
end

local AVISO60 = { "Sale de la guia PvP de WoW Forever (WoWForeverBuilds, hecha para el tope del juego): aqui solo lo que tienes hasta el nivel 30. Aun no hay guia PvP de Forever para nivel 30; se actualizara.",
  "From the WoW Forever PvP guide (WoWForeverBuilds, made for max level): only what you have up to level 30. There is no Forever PvP guide for level 30 yet; it will be updated." }
local NOTA_PVP = {
  WARRIOR = AVISO60, ROGUE = AVISO60, DRUID = AVISO60, MAGE = AVISO60, WARLOCK = AVISO60, PRIEST = AVISO60,
  PALADIN = AVISO60, HUNTER = AVISO60, SHAMAN = AVISO60,
}
WowF.datosPvP = function() return PVP, FUENTE_PVP end -- para las pruebas
local ROLES = {
  control = { "Control", "Control" }, interrupcion = { "Interrumpir", "Interrupt" }, defensiva = { "Defensiva", "Defensive" },
  dano = { "Dano", "Damage" }, movilidad = { "Movilidad", "Mobility" }, racial = { "Racial", "Racial" },
}

-- Raciales utiles en PvP (datos/razas.js de Forever). La raza se mira por el archivo de raza del cliente y, si el cliente
-- conoce el hechizo, tambien por IsPlayerSpell: nunca sale la racial de otra raza ni de la otra faccion.
local RACIALES = {
  { "Will to Survive", 1259718, { Human = true }, "defensiva", "Quita al instante los aturdimientos: guardala para el stun que te va a matar (Rogue, Warrior, Paladin).", "Instantly removes stuns: save it for the stun that would kill you (Rogue, Warrior, Paladin)." },
  { "Perception", 20600, { Human = true }, "defensiva", "Ves mucho mejor a los que van en sigilo durante 20 s: usala si sospechas de un Rogue o un Druid gato.", "Much better stealth detection for 20 s: use it when you suspect a Rogue or a cat Druid." },
  { "Blood Fury", 20572, { Orc = true }, "dano", "Mas 10 % de poder de ataque y con hechizos durante 15 s, cada 2 min: usala al empezar tu golpe fuerte.", "+10% attack and spell power for 15 s, every 2 min: use it as you start your burst." }, -- notas-70425 L259; 2 min: Blizzard 26-oct post 7, Berserking 15 s: post 8 (27-oct)
  { "Shatter Curse", 1299026, { Orc = true }, "defensiva", "Quita miedos, maldiciones y Banes y baja un 5 % el dano magico 8 s (ya no da inmunidad): contra el Fear de Warlock o Priest.", "Removes fears, Curses and Banes and lowers magic damage taken by 5% for 8 s (no longer grants immunity): against Warlock or Priest Fear." }, -- notas-70425 L263
  { "Stoneform", 20594, { Dwarf = true }, "defensiva", "Quita sangrados, venenos y enfermedades y te protege 8 s: muy buena contra Rogue y Warrior.", "Removes bleeds, poisons and diseases and protects you for 8 s: great against Rogues and Warriors." },
  { "Shadowmeld", 20580, { NightElf = true }, "movilidad", "Te escondes mientras no te muevas: para esperar a un enemigo o perderte de vista.", "Hide while you stand still: to ambush an enemy or drop out of sight." },
  { "Elune's Light", 1259799, { NightElf = true }, "dano", "Mas 10 % de critico durante 15 s: usala con tu golpe fuerte.", "+10% crit for 15 s: use it with your burst." },
  { "Will of the Forsaken", 7744, { Scourge = true, Undead = true }, "defensiva", "Quita miedo, embelesamiento y sueno: guardala para el Fear de Warlock o Priest.", "Removes fear, charm and sleep: save it for a Warlock or Priest Fear." },
  { "Cannibalize", 20577, { Scourge = true, Undead = true }, "defensiva", "Tras la pelea, junto a un cadaver humanoide o no-muerto: recuperas vida y mana rapido.", "After a fight, next to a humanoid or undead corpse: recover health and mana fast." },
  { "War Stomp", 20549, { Tauren = true }, "control", "Aturde 2 s a los enemigos a 8 m, cada 90 s: para cortar un hechizo o para huir.", "Stuns enemies within 8 yd for 2 s, every 90 s: to stop a cast or to escape." }, -- notas-70425 L281
  { "Escape Artist", 20589, { Gnome = true }, "movilidad", "Te libra de raices y frenados y te da 3 s de inmunidad: contra Frost Nova, Hamstring o Entangling Roots.", "Frees you from roots and slows with 3 s of immunity: against Frost Nova, Hamstring or Entangling Roots." },
  { "Eureka!", 1259812, { Gnome = true }, "dano", "10 % menos de costo y 10 % mas de dano en tus golpes no periodicos durante 8 s, cada 2 min (Priest: tambien curas): usala al empezar tu golpe fuerte.", "10% lower cost and 10% more damage on your non-periodic abilities for 8 s, every 2 min (Priest: heals too): use it as you start your burst." }, -- datos/razas.js y SpellCooldowns.csv (build 70790: 120000 ms)
  { "Berserking", 20554, { Troll = true }, "dano", "Mas 10 % de velocidad de ataque y de lanzamiento 15 s: usala con tu golpe fuerte.", "+10% attack and casting speed for 15 s: use it with your burst." },
}
local function razaJugador()
  if not UnitRace then return nil end
  local ok, _, archivo = pcall(UnitRace, "player")
  if not ok then return nil end
  return (WowF.numero and WowF.numero(archivo)) or (type(archivo) == "string" and archivo) or nil
end
-- Raciales de PvP de tu raza (con el id que conoce el cliente)
local function racialesPvP()
  local raza, l = razaJugador(), {}
  for _, r in ipairs(RACIALES) do
    local ok, si = pcall(IsPlayerSpell or function() end, r[2])
    if (raza and r[3][raza]) or (ok and si) then table.insert(l, r) end
  end
  return l
end
WowF.racialesPvP = function() local t = {}; for _, r in ipairs(racialesPvP()) do table.insert(t, r[1]) end; return t end -- para las pruebas

-- Lista PvP de tu rama: la de la rama, o la comun de la clase ("_"); nil = sin guia verificada
local function listaPvP(clase, rama)
  local c = PVP[clase or ""]
  if not c then return nil end
  return c[rama] or c._
end

-- ===================== Modo: PvE o PvP =====================
local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function valor(f, ...) -- valor del juego que puede ser secreto (WowF.llamar de wowF_Exportar.lua)
  if WowF.llamar then return WowF.llamar(f, ...) end
  if type(f) ~= "function" then return nil end
  local ok, v = pcall(f, ...)
  if ok and v ~= nil and not (issecretvalue and issecretvalue(v)) then return tostring(v) end
end
-- Estas en un campo de batalla, en una arena o con el PvP activado?
local function enPvP()
  if valor(UnitIsPVP, "player") == "true" then return true end
  local zona = valor(GetZonePVPInfo)
  if zona == "combat" or zona == "arena" then return true end
  if IsInInstance then
    local ok, _, tipo = pcall(IsInInstance)
    tipo = ok and WowF.numero and WowF.numero(tipo) or (ok and type(tipo) == "string" and tipo) or nil
    if tipo == "pvp" or tipo == "arena" then return true end
  end
  return false
end
local function modoRotacion()
  local db = WowFExportarDB and WowFExportarDB.modoRotacion
  local m = db and db[clavePj()]
  if m == "pve" or m == "pvp" then return m end
  return enPvP() and "pvp" or "pve"
end
function WowF.modoRotacion(nuevo) -- sin argumento: el modo de ahora; "pve"/"pvp": lo guarda para este personaje
  if nuevo == "pve" or nuevo == "pvp" then
    if WowFExportarDB then WowFExportarDB.modoRotacion = WowFExportarDB.modoRotacion or {}; WowFExportarDB.modoRotacion[clavePj()] = nuevo end
    if WowF.libroRedibujar then pcall(WowF.libroRedibujar) end
  end
  return modoRotacion()
end

-- ===================== Contenido: Rotacion =====================
local mostrarCopia -- se define mas abajo (ventana para copiar)
-- Renglon de la fuente: nombre y enlace a la vista; clic = ventana con los enlaces para copiarlos
local function lineaFuente(item, fuentes, titulo)
  if not fuentes or #fuentes == 0 then return end
  local nombres, urls = {}, {}
  for _, f in ipairs(fuentes) do table.insert(nombres, f[1]); table.insert(urls, f[2]) end
  item({ texto = CELESTE .. L("Fuente: ", "Source: ") .. "|r" .. BLANCO .. table.concat(nombres, " + ") .. "|r",
    sub = GRIS .. table.concat(urls, "\n") .. "|r" .. "\n" .. ORO .. L("Clic: copiar los enlaces", "Click: copy the links") .. "|r",
    icono = "Interface\\Icons\\INV_Misc_Book_09", chico = true,
    ayuda = titulo .. "\n" .. table.concat(urls, "\n") .. "\n\n" .. L("Clic: abre los enlaces para copiarlos (Ctrl+C).", "Click: opens the links to copy them (Ctrl+C)."),
    accion = function() if mostrarCopia then mostrarCopia(titulo, table.concat(urls, "\n")) end end })
end

-- Golpe que ya tienes: numerado, clic = tomarlo para la barra
local function itemConocido(item, i, nombre, sub, ayudaTxt, h)
  local id = idConocido(h)
  item({ texto = VERDE .. i .. ". |r" .. BLANCO .. nombre .. "|r", sub = sub, icono = iconoHechizo(id), chico = true,
    ayuda = nombre .. "\n" .. ayudaTxt .. "\n\n" .. L("Clic: lo tomas con el raton para soltarlo en tu barra.", "Click: pick it up to drop it on your bar."),
    accion = function()
      if InCombatLockdown and InCombatLockdown() then return end
      if C_Spell and C_Spell.PickupSpell then pcall(C_Spell.PickupSpell, id) elseif PickupSpell then pcall(PickupSpell, id) end
    end })
end

local function botonesModo(item, modo)
  item({ texto = (modo == "pve" and VERDE or BLANCO) .. "PvE|r" .. GRIS .. "  ·  " .. L("subir de nivel y mazmorras", "leveling and dungeons") .. "|r",
    icono = "Interface\\Icons\\INV_Sword_04", chico = true, boton = modo == "pve" and "elegido" or "si",
    ayuda = "PvE\n" .. L("Rotacion para subir de nivel y para mazmorras.", "Rotation for leveling and dungeons."),
    accion = function() WowF.modoRotacion("pve") end })
  item({ texto = (modo == "pvp" and VERDE or BLANCO) .. "PvP|r" .. GRIS .. "  ·  " .. L("duelos, campos de batalla y PvP de mundo", "duels, battlegrounds and world PvP") .. "|r",
    icono = "Interface\\Icons\\INV_BannerPVP_02", chico = true, boton = modo == "pvp" and "elegido" or "si",
    ayuda = "PvP\n" .. L("Que usar contra jugadores: control, interrupciones, defensivas y tus raciales.", "What to use against players: control, interrupts, defensives and your racials."),
    accion = function() WowF.modoRotacion("pvp") end })
end

local function contenidoPvE(p, clase, rama, cab, nota, item)
  local porClase = ROT[clase or ""] or {}
  local lista = porClase[rama]
  if not lista then lista = WowF._primeraRama(porClase) end
  if not lista then nota(GRIS .. L("Aun no hay rotacion para tu clase.", "No rotation for your class yet.") .. "|r"); return end
  cab(ORO .. L("Rotacion: ", "Rotation: ") .. rama .. "|r")
  lineaFuente(item, fuentesPvE(clase, rama), L("Rotacion PvE: ", "PvE rotation: ") .. rama)
  if NOTA[clase or ""] then nota(CELESTE .. L(NOTA[clase][1], NOTA[clase][2]) .. "|r") end
  local ahora, despues = {}, {}
  for i, r in ipairs(lista) do
    local color, texto, ya, h = estado(p, clase, r[1])
    -- nivel para ordenar "Mas adelante": el del plan si es talento, el del entrenador si no (lo que no llega, al final)
    local nv = esTalento(clase, r[1]) and (nivelEnPlan(p, r[1]) or 999) or (h and (h[1] or 1) > 1 and h[1]) or 998
    table.insert(ya and ahora or despues, { r = r, color = color, texto = texto, h = h, nv = nv, i = i })
  end
  table.sort(despues, function(a, b) if a.nv ~= b.nv then return a.nv < b.nv end return a.i < b.i end)
  if #ahora == 0 then nota(GRIS .. L("Todavia no tienes ninguno de estos golpes: sube un poco y visita a tu entrenador.", "You don't know any of these yet: level a bit and visit your trainer.") .. "|r") end
  for i, e in ipairs(ahora) do itemConocido(item, i, e.r[1], GRIS .. L(e.r[2], e.r[3]) .. "|r", L(e.r[2], e.r[3]), e.h) end
  cab(GRIS .. L("Mas adelante", "Later") .. "|r")
  if #despues > 0 then
    for _, e in ipairs(despues) do
      item({ texto = e.color .. e.r[1] .. "|r" .. GRIS .. "  ·  " .. e.texto .. "|r", sub = GRIS .. L(e.r[2], e.r[3]) .. "|r",
        icono = iconoHechizo(e.h and e.h[2]), chico = true })
    end
  else
    nota(GRIS .. L("Ya tienes todos los golpes de tu rotacion hasta el nivel 30 (tope de la beta). Cada pocos niveles vuelve a tu entrenador por los rangos nuevos.",
      "You already know every ability in your rotation up to level 30 (beta cap). Every few levels, visit your trainer for new ranks.") .. "|r")
  end
end

local function contenidoPvP(p, clase, rama, cab, nota, item)
  cab(ORO .. L("Rotacion PvP: ", "PvP rotation: ") .. rama .. "|r")
  local lista = listaPvP(clase, rama)
  local nivel = UnitLevel("player") or 1
  if SIN_PVP_FOREVER[clase or ""] then
    nota(NARANJA .. L("Rotacion PvP de Forever aun no disponible para tu clase: se muestra la PvE. Se actualizara en proximas actualizaciones.",
      "Forever PvP rotation not available for your class yet: showing PvE. It will be updated in future updates.") .. "|r")
    contenidoPvE(p, clase, rama, cab, nota, item)
  elseif not lista then
    nota(NARANJA .. L("Sin guia PvP verificada todavia para tu rama: usa la rotacion PvE y tus raciales.", "No verified PvP guide yet for your spec: use the PvE rotation and your racials.") .. "|r")
  else
    lineaFuente(item, fuentesPvP(clase, rama),L("Rotacion PvP: ", "PvP rotation: ") .. rama)
    if NOTA_PVP[clase or ""] then nota(CELESTE .. L(NOTA_PVP[clase][1], NOTA_PVP[clase][2]) .. "|r") end
    local ahora, falta, despues = {}, {}, {}
    for i, r in ipairs(lista) do
      local color, texto, ya, h = estado(p, clase, r[1])
      local nv = esTalento(clase, r[1]) and (nivelEnPlan(p, r[1]) or 999) or (h and (h[1] or 1) > 1 and h[1]) or 998
      local e = { r = r, color = color, texto = texto, h = h, nv = nv, i = i }
      local tope = (WowFDatos and WowFDatos.topeBeta) or 30
      if not ya and nv > tope and nv ~= 998 then
        -- llega despues del tope de la beta: no se muestra
      elseif ya then table.insert(ahora, e)
      elseif nv <= nivel or color == NARANJA then table.insert(falta, e)
      else table.insert(despues, e) end
    end
    table.sort(despues, function(a, b) if a.nv ~= b.nv then return a.nv < b.nv end return a.i < b.i end)
    if #ahora == 0 then nota(GRIS .. L("Todavia no tienes ninguno de estos golpes: sube un poco y visita a tu entrenador.", "You don't know any of these yet: level a bit and visit your trainer.") .. "|r") end
    for i, e in ipairs(ahora) do
      local rol = ROLES[e.r[2]] or ROLES.dano
      itemConocido(item, i, e.r[1] .. GRIS .. "  ·  " .. L(rol[1], rol[2]) .. "|r", GRIS .. L(e.r[3], e.r[4]) .. "|r", L(rol[1], rol[2]) .. ": " .. L(e.r[3], e.r[4]), e.h)
    end
    if #falta > 0 then
      cab(NARANJA .. L("Te falta", "Missing") .. "|r")
      for _, e in ipairs(falta) do
        local como, accion = comoAprender(p, clase, e.r[1])
        local rol = ROLES[e.r[2]] or ROLES.dano
        item({ texto = NARANJA .. L("Te falta: ", "Missing: ") .. e.r[1] .. "|r" .. GRIS .. " - " .. como .. "|r",
          sub = GRIS .. L(rol[1], rol[2]) .. ": " .. L(e.r[3], e.r[4]) .. "|r", icono = iconoHechizo(e.h and e.h[2]), chico = true,
          ayuda = e.r[1] .. "\n" .. L(e.r[3], e.r[4]) .. "\n" .. L("Te falta: ", "Missing: ") .. e.r[1] .. " - " .. como .. "\n\n"
            .. (accion == "talentos" and L("Clic: abre la pestana Talentos.", "Click: opens the Talents tab.") or L("Clic: te marco el entrenador en el mapa.", "Click: I mark your trainer on the map.")),
          accion = function()
            if accion == "talentos" then if WowF.abrirLibro then WowF.abrirLibro("Talentos") end
            elseif WowF.irAlEntrenador then WowF.irAlEntrenador(L("aprender ", "learn ") .. e.r[1]) end
          end })
      end
    end
    cab(GRIS .. L("Mas adelante", "Later") .. "|r")
    if #despues > 0 then
      for _, e in ipairs(despues) do
        local rol = ROLES[e.r[2]] or ROLES.dano
        item({ texto = e.color .. e.r[1] .. "|r" .. GRIS .. "  ·  " .. e.texto .. "|r", sub = GRIS .. L(rol[1], rol[2]) .. ": " .. L(e.r[3], e.r[4]) .. "|r",
          icono = iconoHechizo(e.h and e.h[2]), chico = true })
      end
    else
      nota(GRIS .. L("Ya tienes todo lo de tu rotacion PvP hasta el nivel 30 (tope de la beta).", "You already know everything in your PvP rotation up to level 30 (beta cap).") .. "|r")
    end
  end
  -- Raciales de tu raza
  local rac = racialesPvP()
  cab(CELESTE .. L("Raciales de tu raza", "Your racials") .. "|r")
  if #rac == 0 then nota(GRIS .. L("Tu raza no tiene raciales que se activen en PvP.", "Your race has no active racials for PvP.") .. "|r") end
  for _, r in ipairs(rac) do
    local rol = ROLES[r[4]] or ROLES.racial
    local id = r[2]
    item({ texto = CELESTE .. r[1] .. "|r" .. GRIS .. "  ·  " .. L(rol[1], rol[2]) .. "|r", sub = GRIS .. L(r[5], r[6]) .. "|r", icono = iconoHechizo(id), chico = true,
      ayuda = r[1] .. "\n" .. L(r[5], r[6]) .. "\n\n" .. L("Clic: la tomas con el raton para soltarla en tu barra.", "Click: pick it up to drop it on your bar."),
      accion = function()
        if InCombatLockdown and InCombatLockdown() then return end
        if C_Spell and C_Spell.PickupSpell then pcall(C_Spell.PickupSpell, id) elseif PickupSpell then pcall(PickupSpell, id) end
      end })
  end
end

function WowF.contenidoRotacion(p, cab, nota, item, separador)
  local clase = p.clase or claseJugador()
  local rama = ramaAhora(p)
  local modo = modoRotacion()
  nota(BLANCO .. L("Que golpes usar y en que orden, para tu rama y tu nivel.", "Which abilities to use and in what order, for your spec and level.") .. "|r")
  nota(VERDE .. "1.|r " .. L("Arriba = lo mas importante. Usa el primero que este listo.", "Top = most important. Use the first one that is ready."))
  nota(ORO .. "2.|r " .. L("Lo que esta en DORADO lo tendras mas adelante.", "What is in GOLD you will get later."))
  nota(BLANCO .. "3.|r " .. L("Clic en un golpe que ya tienes: lo tomas para ponerlo en tu barra.", "Click an ability you know: pick it up to place it on your bar."))
  botonesModo(item, modo)
  if WowF.itemAprendizaje then WowF.itemAprendizaje(item) end -- 13-oct: Modo aprendizaje
  separador()
  if modo == "pvp" then contenidoPvP(p, clase, rama, cab, nota, item) else contenidoPvE(p, clase, rama, cab, nota, item) end
end

-- ===================== Macros: crear y copiar =====================
-- {A|B|C}: el primero que ya sepas; si no sabes ninguno, el de menor nivel (en empate, el ultimo: el basico).
-- Devuelve nombre, datos, si lo sabes, nivel minimo y nombre del de menor nivel
local function alternativa(clase, txt)
  local sabe, menor
  for n in txt:gmatch("[^|]+") do
    local h = hechizo(clase, n)
    if h then
      if not sabe and lotengo(h) then sabe = { n, h } end
      if not menor or (h[1] or 1) <= (menor[2][1] or 1) then menor = { n, h } end
    end
  end
  if not menor then return nil end
  local e = sabe or menor
  return e[1], e[2], sabe ~= nil, menor[2][1] or 1, menor[1]
end
WowF.alternativaMacro = alternativa -- para las pruebas

local function cuerpoMacro(clase, cuerpo)
  return (cuerpo:gsub("{([^}]+)}", function(txt)
    local n, h = alternativa(clase, txt)
    return nombreCliente(h and h[2], n or txt:match("[^|]+"))
  end):gsub("%[known:([^%]]+)%]", function(n)
    local h = hechizo(clase, n)
    return "[known:" .. nombreCliente(h and h[2], n) .. "]"
  end))
end

local CON_MASCOTA = { HUNTER = true, WARLOCK = true }
-- Devuelve nil si la macro no es de tu clase; si lo es: nivel en que sirve, hechizos que aun no sabes y (16-oct) sus "extra":
-- hechizos que la macro usa cuando los aprendes, sin esperar por ellos (ya sabidos / los que llegan: { nombre, nivel }).
local function revisarMacro(clase, m, p)
  if m[3]:find("/pet", 1, true) and not CON_MASCOTA[clase or ""] then return nil end
  local opcional, extra = {}, {}
  for n in m[3]:gmatch("%[known:([^%]]+)%]") do opcional[n] = true end
  for _, n in ipairs(m.extra or {}) do extra[n] = true end
  local nivel, faltan, extSabe, extLuego, vistos = m[1], {}, {}, {}, {}
  for txt in m[3]:gmatch("{([^}]+)}") do
    local n, h, sabe, nvMin, nMin = alternativa(clase, txt)
    if not h then return nil end
    -- Talento (WowFHechizos le pone nivel 1): no llega antes del nivel de su fila (10, 15, 20...)
    local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[clase or ""]
    local ta = c and c.talentos and c.talentos[nMin]
    if ta then
      nvMin = math.max(nvMin or 1, 10 + ((tonumber(ta[4]) or 1) - 1) * 5)
      -- Con plan: el nivel en que tu guia lo coge (si es de la rama final de un plan mixto, no antes del cambio)
      local np = p and nivelEnPlan(p, nMin)
      if np then nvMin = math.max(nvMin, np)
      elseif p and (tonumber(p.ramaCambio) or 0) > 0 then nvMin = math.max(nvMin, tonumber(p.ramaCambio)) end
    end
    if extra[txt] then
      if not vistos[txt] then
        vistos[txt] = true
        if sabe then table.insert(extSabe, n) else table.insert(extLuego, { nombre = nMin, nivel = nvMin }) end
      end
    elseif not opcional[txt] then
      if nvMin > nivel then nivel = nvMin end
      if not sabe then table.insert(faltan, nMin) end
    end
  end
  return nivel, faltan, extSabe, extLuego
end
WowF.revisarMacro = revisarMacro -- para las pruebas

-- 16-oct: macros de tu clase para la rama con la que subes AHORA (las que no llevan rama sirven a todas).
-- "Feral Combat (Cat)" vale para una macro de "Feral Combat"; sin plan = todas.
local function macrosPara(clase, p)
  local rama = p and ramaAhora(p) or ""
  local function vale(m)
    if not m.rama or rama == "" then return true end
    for _, r in ipairs(m.rama) do
      if r == rama or rama:find(r .. " (", 1, true) == 1 then return true end
    end
    return false
  end
  local l = {}
  for _, m in ipairs(MAC.TODAS) do if vale(m) then table.insert(l, m) end end
  for _, m in ipairs(MAC[clase or ""] or {}) do if vale(m) then table.insert(l, m) end end
  return l
end
WowF.macrosPara = macrosPara -- para las pruebas
-- Texto de los "extra" que aun no sabes: "Charge (nivel 4), Intercept (nivel 24)"
local function textoExtras(lista)
  local t = {}
  for _, x in ipairs(lista or {}) do table.insert(t, x.nombre .. " (" .. L("nivel ", "level ") .. x.nivel .. ")") end
  return table.concat(t, ", ")
end
WowF.textoExtrasMacro = textoExtras

local function crearMacro(nombre, cuerpo)
  if InCombatLockdown and InCombatLockdown() then
    print("|cff33ccffForever Guide|r: " .. L("no se pueden crear macros en combate.", "macros can't be created in combat.")); return
  end
  if not CreateMacro then return end
  local existe = indiceMacro(nombre)
  nombre = nombreMacro(nombre)
  local ok, err
  if existe and existe > 0 and EditMacro then ok, err = pcall(EditMacro, existe, nombre, "INV_Misc_QuestionMark", cuerpo)
  else ok, err = pcall(CreateMacro, nombre, "INV_Misc_QuestionMark", cuerpo, true) end
  if ok then
    print("|cff33ccffForever Guide|r: " .. L("macro creada: ", "macro created: ") .. ORO .. nombre .. "|r" .. L(". Abrela con /macro (pestana del personaje) y arrastrala a tu barra.", ". Open /macro (character tab) and drag it to your bar."))
  else
    print("|cff33ccffForever Guide|r: " .. L("no se pudo crear (quiza ya tienes 18 macros del personaje). Copiala a mano.", "couldn't create it (maybe you already have 18 character macros). Copy it by hand."))
  end
end

-- Ventanita para copiar: el texto sale seleccionado, Ctrl+C
local copia
function mostrarCopia(nombre, cuerpo) -- local declarado arriba (lo usa la rotacion)
  if not copia then
    copia = CreateFrame("Frame", "wowFCopiaMacro", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    copia:SetSize(380, 190)
    copia:SetPoint("CENTER")
    copia:SetFrameStrata("DIALOG")
    -- 11-oct (hibrido): cabecera pequena, nombre de la macro en serif, texto en una tarjeta de piedra
    local E = WowF.estilo
    copia:SetHeight(210)
    E.marco(copia, "panel")
    copia:EnableMouse(true)
    copia.cab = E.cabecera(copia, 20)
    copia.cab.titulo:SetText("Forever Guide")
    copia.titulo = E.titulo(copia, nil, 13)
    copia.titulo:SetPoint("TOPLEFT", 14, -34)
    copia.titulo:SetPoint("RIGHT", copia, "RIGHT", -14, 0)
    copia.hoja = E.tarjeta(copia)
    copia.hoja:SetPoint("TOPLEFT", 12, -56)
    copia.hoja:SetPoint("BOTTOMRIGHT", -12, 42)
    local caja = CreateFrame("EditBox", nil, copia)
    caja:SetMultiLine(true)
    caja:SetFontObject(ChatFontNormal)
    caja:SetPoint("TOPLEFT", 20, -62)
    caja:SetPoint("BOTTOMRIGHT", -20, 48)
    if caja.SetFrameLevel and copia.hoja.GetFrameLevel then pcall(function() caja:SetFrameLevel(copia.hoja:GetFrameLevel() + 2) end) end
    caja:SetAutoFocus(true)
    caja:SetScript("OnEscapePressed", function() copia:Hide() end)
    copia.caja = caja
    local cerrar = CreateFrame("Button", nil, copia, "UIPanelButtonTemplate")
    WowF.estilo.boton(cerrar, "cuero")
    cerrar:SetSize(90, 22)
    cerrar:SetPoint("BOTTOMRIGHT", -14, 12)
    cerrar:SetText(L("Cerrar", "Close"))
    cerrar:SetScript("OnClick", function() copia:Hide() end)
    WowF.cerrarConEsc("wowFCopiaMacro")
  end
  copia.titulo:SetText(nombre .. "  " .. GRIS .. L("Ctrl+C para copiar", "Ctrl+C to copy") .. "|r")
  copia.caja:SetText(cuerpo)
  copia:Show()
  copia.caja:SetFocus()
  copia.caja:HighlightText()
end
WowF.cuerpoMacro, WowF.crearMacro = cuerpoMacro, crearMacro -- para las pruebas

-- ===================== Contenido: Macros =====================
-- Etiqueta de uso de cada macro (16-oct: tambien "Solo PvP")
local function etiquetaUso(uso, conColor)
  local t, c
  if uso == "pve" then t, c = L("Solo PvE", "PvE only"), NARANJA
  elseif uso == "pvp" then t, c = L("Solo PvP", "PvP only"), ORO
  else t, c = L("PvE y PvP", "PvE and PvP"), CELESTE end
  if conColor then return c .. t .. "|r" end
  return t
end
WowF.etiquetaUsoMacro = etiquetaUso
-- Lineas "En PvE / En PvP / Cuando" de una macro, segun su uso (con color si conColor)
local function lineasUso(m, uso, pvp, conColor)
  local function c(col, s) return conColor and (col .. s .. "|r") or s end
  local cuando = m[6] and L(m[6], m[7])
  local t = ""
  if uso == "pvp" then
    if cuando then t = t .. "\n" .. c(BLANCO, L("En PvP: ", "In PvP: ")) .. c(GRIS, cuando) end
    t = t .. "\n" .. c(NARANJA, L("En PvE: ", "In PvE: ")) .. c(GRIS, L("no la necesitas; es para pelear contra jugadores.", "you don't need it; it's for fighting players."))
  else
    if cuando then t = t .. "\n" .. c(BLANCO, pvp and L("En PvE: ", "In PvE: ") or L("Cuando: ", "When: ")) .. c(GRIS, cuando) end
    if pvp then t = t .. "\n" .. c(CELESTE, L("En PvP: ", "In PvP: ")) .. c(GRIS, L(pvp[1], pvp[2])) end
    if uso == "pve" then t = t .. "\n" .. c(NARANJA, L("En PvP: ", "In PvP: ")) .. c(GRIS, L("no la uses contra jugadores; es para PvE.", "don't use it against players; it's for PvE.")) end
  end
  return t
end
-- Fuente, rama y lo que la macro usara mas adelante
local function lineasExtra(m, extLuego, conColor)
  local function c(col, s) return conColor and (col .. s .. "|r") or s end
  local t = ""
  if m.rama then t = t .. "\n" .. c(GRIS, L("Para tu rama: ", "For your spec: ") .. table.concat(m.rama, ", ")) end
  if extLuego and #extLuego > 0 then t = t .. "\n" .. c(CELESTE, L("Mas adelante tambien usara: ", "Later it will also use: ")) .. c(GRIS, textoExtras(extLuego)) end
  if m.fuente then t = t .. "\n" .. c(GRIS, L("Fuente: ", "Source: ") .. m.fuente.nombre .. " (WoW Forever)") end
  return t
end
function WowF.contenidoMacros(p, cab, nota, item, separador)
  local clase = p.clase or claseJugador()
  local nivel = UnitLevel("player") or 1
  nota(BLANCO .. L("Macros utiles para tu clase y tu rama: un boton que hace varias cosas.", "Useful macros for your class and spec: one button that does several things.") .. "|r")
  nota(VERDE .. "1.|r " .. L("Clic en una macro VERDE: se crea sola en tu lista (/macro, pestana del personaje).", "Click a GREEN macro: it is created in your list (/macro, character tab)."))
  nota(BLANCO .. "2.|r " .. L("Abre /macro y arrastrala a tu barra.", "Open /macro and drag it to your bar."))
  nota(ORO .. "3.|r " .. L("Mayus+clic: ver el texto para copiarlo a mano.", "Shift+click: show the text to copy it by hand."))
  nota(NARANJA .. L("NARANJA", "ORANGE") .. "|r = " .. L("te falta aprender una habilidad para que funcione completa: dice cual y como; clic y te marco el entrenador.", "you still need to learn an ability for it to fully work: it says which and how; click and I mark your trainer."))
  nota(CELESTE .. "4.|r " .. L("Las que ya creaste se actualizan solas al aprender un hechizo mejor, y te aviso en pantalla.", "The ones you created update themselves when you learn a better spell, and you get an on-screen notice."))
  nota(CELESTE .. L("PvE y PvP", "PvE and PvP") .. "|r = " .. L("sirve en los dos; si contra jugadores se usa distinto, lo dice en \"En PvP\". ", "works in both; if it's used differently against players, \"In PvP\" says how. ")
    .. NARANJA .. L("Solo PvE", "PvE only") .. "|r = " .. L("no la uses contra jugadores. ", "don't use it against players. ")
    .. ORO .. L("Solo PvP", "PvP only") .. "|r = " .. L("es para pelear contra jugadores.", "it's for fighting players."))
  nota(GRIS .. L("Cada macro dice de que guia de WoW Forever sale (Fuente).", "Each macro says which WoW Forever guide it comes from (Source).") .. "|r")
  separador()
  local ya, luego = {}, {}
  for _, m in ipairs(macrosPara(clase, p)) do
    local nv, faltan, _, extLuego = revisarMacro(clase, m, p)
    if nv then table.insert(nv <= nivel and ya or luego, { m = m, nv = nv, faltan = faltan, extLuego = extLuego }) end
  end
  if #ya == 0 and #luego == 0 then
    nota(NARANJA .. L("Aun no hay datos de WoW Forever para las macros de tu clase; pendiente de actualizar.", "No WoW Forever data yet for your class macros; pending update.") .. "|r")
    return
  end
  table.sort(ya, function(a, b) return a.nv < b.nv end)
  table.sort(luego, function(a, b) return a.nv < b.nv end)
  local function pintar(e)
    local m = e.m
    local cuerpo = cuerpoMacro(clase, m[3])
    local listo = e.nv <= nivel
    local falta = listo and #e.faltan > 0
    local estadoTxt = (not listo and (L("a nivel ", "at level ") .. e.nv))
      or (falta and L("te falta aprender algo · clic: como", "something to learn first · click: how"))
      or L("clic: crear", "click: create")
    local color = (not listo and ORO) or (falta and NARANJA) or VERDE
    -- Lo que falta para que la macro funcione completa, cada cosa con como se aprende
    local txtFalta, ayudaFalta, irA = "", "", nil
    if falta then
      local dichos = {} -- 4-oct: una macro que usa el mismo hechizo dos veces lo decia dos veces
      for _, n in ipairs(e.faltan) do if not dichos[n] then dichos[n] = true
        local como, accion = comoAprender(p, clase, n)
        txtFalta = txtFalta .. "\n" .. NARANJA .. L("Te falta: ", "Missing: ") .. n .. "|r" .. GRIS .. " - " .. como .. "|r"
        ayudaFalta = ayudaFalta .. "\n" .. L("Te falta: ", "Missing: ") .. n .. " - " .. como
        if accion == "entrenador" or not irA then irA = accion end
      end end
    end
    local uso, pvp = usoMacro(clase, m)
    item({ texto = color .. nombreMacro(m[2]) .. "|r" .. GRIS .. "  ·  |r" .. etiquetaUso(uso, true) .. GRIS .. "  ·  " .. estadoTxt .. "|r",
      sub = GRIS .. L(m[4], m[5]) .. "|r" .. lineasUso(m, uso, pvp, true) .. txtFalta .. lineasExtra(m, e.extLuego, true),
      icono = "Interface\\Icons\\INV_Misc_Note_01", chico = true,
      ayuda = nombreMacro(m[2]) .. " (" .. etiquetaUso(uso) .. ")\n" .. L(m[4], m[5]) .. lineasUso(m, uso, pvp)
        .. ayudaFalta .. lineasExtra(m, e.extLuego) .. "\n\n" .. cuerpo .. "\n\n"
        .. (falta and L("Clic: te marco el entrenador en el mapa.  Mayus+clic: copiarla igual.", "Click: I mark your trainer on the map.  Shift+click: copy it anyway.")
          or L("Clic: crearla.  Mayus+clic: copiarla.", "Click: create it.  Shift+click: copy it.")),
      accion = function()
        if IsShiftKeyDown and IsShiftKeyDown() then mostrarCopia(nombreMacro(m[2]), cuerpo); return end
        if not falta then crearMacro(m[2], cuerpo); return end
        print("|cff33ccffForever Guide|r: " .. nombreMacro(m[2]) .. ayudaFalta:gsub("\n", "\n  "))
        if irA == "talentos" then
          if WowF.abrirLibro then WowF.abrirLibro("Talentos") end
        elseif WowF.irAlEntrenador then
          WowF.irAlEntrenador(L("aprender ", "learn ") .. table.concat(e.faltan, ", "))
        end
      end })
  end
  if #ya > 0 then cab(VERDE .. L("Ya puedes usarlas", "Ready to use") .. "|r") end
  for _, m in ipairs(ya) do pintar(m) end
  if #luego > 0 then cab(ORO .. L("Mas adelante", "Later") .. "|r") end
  for _, m in ipairs(luego) do pintar(m) end
end
-- ===================== Datos para la vista por tarjetas (11-oct, wowF_VistaCombate.lua) =====================
-- Lo mismo que pintan contenidoRotacion/contenidoMacros, pero como datos: la vista nueva dibuja tarjetas con esto.
-- No cambia nada de lo de arriba (el Libro sigue pintando lo viejo si la vista falla).
WowF.mostrarCopiaMacro = function(nombre, cuerpo) if mostrarCopia then mostrarCopia(nombre, cuerpo) end end
WowF.iconoHechizo = WowF.iconoHechizo or iconoHechizo
-- Tomar un hechizo con el raton para la barra (fuera de combate)
function WowF.tomarHechizo(id)
  if not id or (InCombatLockdown and InCombatLockdown()) then return end
  if C_Spell and C_Spell.PickupSpell then pcall(C_Spell.PickupSpell, id) elseif PickupSpell then pcall(PickupSpell, id) end
end
-- Totems del Shaman por elemento (NOTA de SHAMAN: Icy Veins /wow-forever; cada elemento llega con una mision de clase)
-- 15-oct: rama de relleno elegida siempre igual (pairs no tiene orden fijo)
function WowF._primeraRama(t)
  local k
  for kk in pairs(t or {}) do if k == nil or tostring(kk) < tostring(k) then k = kk end end
  return k ~= nil and t[k] or nil
end
local TOTEMS = { { "Earth", 4, "Strength of Earth Totem" }, { "Fire", 10, "Searing Totem" }, { "Water", 20, "Healing Stream Totem" }, { "Air", 30, "Grounding Totem" } }
-- Primer hechizo de la macro ({A|B} = el que sabes o el de menor nivel): para el icono
local function iconoMacro(clase, cuerpo)
  local txt = cuerpo:match("{([^}]+)}")
  if not txt then return nil end
  local _, h = alternativa(clase, txt)
  return h and iconoHechizo(idConocido(h)) or nil
end
local function golpe(p, clase, nombre, desc, rol, i)
  local color, texto, ya, h = estado(p, clase, nombre)
  local nv = esTalento(clase, nombre) and (nivelEnPlan(p, nombre) or 999) or (h and (h[1] or 1) > 1 and h[1]) or 998
  local id = ya and idConocido(h) or (h and h[2])
  local g = { nombre = nombre, desc = desc, ya = ya, nv = nv, i = i, id = id, icono = iconoHechizo(id), estado = texto, rol = rol }
  if not ya then
    -- "nivel N" si se sabe; si no, "mas adelante" (talento sin nivel, o no esta en la clase)
    g.nivel = (nv < 900) and nv or nil
    local tope = (WowFDatos and WowFDatos.topeBeta) or 30
    g.pasaTope = nv > tope and nv ~= 998
    g.falta = (nv <= (UnitLevel("player") or 1)) or color == NARANJA
    if g.falta then g.como, g.accion = comoAprender(p, clase, nombre) end
  end
  return g
end

function WowF.datosVistaCombate(p)
  p = p or {}
  local clase = p.clase or claseJugador()
  local rama = ramaAhora(p)
  local modo = modoRotacion()
  local nivel = UnitLevel("player") or 1
  local d = { clase = clase, rama = rama, modo = modo, nivel = nivel, golpes = {}, raciales = {}, macros = {} }
  -- Rotacion (en el orden de la guia: asi la dibuja la maqueta, con lo que tienes en verde y lo demas en gris)
  if modo == "pvp" and not SIN_PVP_FOREVER[clase or ""] and listaPvP(clase, rama) then
    d.fuentes = fuentesPvP(clase, rama)
    d.nota = NOTA_PVP[clase or ""] and L(NOTA_PVP[clase][1], NOTA_PVP[clase][2]) or nil
    for i, r in ipairs(listaPvP(clase, rama)) do
      local rol = ROLES[r[2]] or ROLES.dano
      local g = golpe(p, clase, r[1], L(r[3], r[4]), L(rol[1], rol[2]), i)
      g.texto, g.rolK = ((r[3] or "") .. " | " .. (r[4] or "")):lower(), r[2] -- 15-oct: para el Modo aprendizaje (clasifica en los dos idiomas)
      if not g.pasaTope then table.insert(d.golpes, g) end -- lo que llega pasado el tope de la beta no se muestra
    end
  else
    if modo == "pvp" then
      d.aviso = SIN_PVP_FOREVER[clase or ""]
        and L("Rotacion PvP de Forever aun no disponible para tu clase: se muestra la PvE. Se actualizara en proximas actualizaciones.",
          "Forever PvP rotation not available for your class yet: showing PvE. It will be updated in future updates.")
        or L("Sin guia PvP verificada todavia para tu rama: usa la rotacion PvE y tus raciales.", "No verified PvP guide yet for your spec: use the PvE rotation and your racials.")
    end
    local porClase = ROT[clase or ""] or {}
    local lista = porClase[rama]
    if not lista then lista = WowF._primeraRama(porClase) end
    d.fuentes = fuentesPvE(clase, rama)
    d.nota = NOTA[clase or ""] and L(NOTA[clase][1], NOTA[clase][2]) or nil
    if not lista then d.sinDatos = L("Aun no hay datos de WoW Forever para la rotacion de tu clase; pendiente de actualizar.", "No WoW Forever data yet for your class rotation; pending update.") end
    for i, r in ipairs(lista or {}) do
      local g = golpe(p, clase, r[1], L(r[2], r[3]), nil, i)
      g.texto = ((r[2] or "") .. " | " .. (r[3] or "")):lower() -- 15-oct: para el Modo aprendizaje
      table.insert(d.golpes, g)
    end
  end
  local ya = 0
  for _, g in ipairs(d.golpes) do if g.ya then ya = ya + 1 end end
  d.tienes = ya
  -- Raciales de tu raza (las mismas de la rotacion PvP)
  local okR, razaNombre = pcall(UnitRace or function() end, "player")
  d.raza = okR and ((WowF.numero and WowF.numero(razaNombre)) or (type(razaNombre) == "string" and razaNombre)) or nil
  for _, r in ipairs(racialesPvP()) do
    local rol = ROLES[r[4]] or ROLES.racial
    table.insert(d.raciales, { nombre = r[1], id = r[2], icono = iconoHechizo(r[2]), desc = L(r[5], r[6]), rol = L(rol[1], rol[2]) })
  end
  -- Totems (solo Shaman)
  if clase == "SHAMAN" then
    d.totems = {}
    for _, t in ipairs(TOTEMS) do
      local h = hechizo(clase, t[3])
      local id = h and (idConocido(h) or h[2])
      table.insert(d.totems, { elemento = t[1], nivel = t[2], totem = t[3], id = id, icono = iconoHechizo(id), ya = lotengo(h) })
    end
  end
  -- Macros (las mismas de contenidoMacros: tu clase y tu rama; ya / luego por nivel)
  for _, m in ipairs(macrosPara(clase, p)) do
    local nv, faltan, _, extLuego = revisarMacro(clase, m, p)
    if nv then
      local uso, pvp = usoMacro(clase, m)
      local e = { clave = m[2], nombre = nombreMacro(m[2]), cuerpo = cuerpoMacro(clase, m[3]), paraQue = L(m[4], m[5]),
        cuando = m[6] and L(m[6], m[7]) or nil, pvp = pvp and L(pvp[1], pvp[2]) or nil, soloPve = uso == "pve", soloPvp = uso == "pvp",
        uso = uso, fuente = m.fuente and m.fuente.nombre or nil, fuenteUrl = m.fuente and m.fuente.url or nil,
        rama = m.rama and table.concat(m.rama, ", ") or nil, extrasPend = extLuego or {}, nv = nv,
        listo = nv <= nivel, faltan = {}, icono = iconoMacro(clase, m[3]) }
      if e.listo then
        local dichos = {}
        for _, n in ipairs(faltan) do if not dichos[n] then dichos[n] = true
          local como, accion = comoAprender(p, clase, n)
          table.insert(e.faltan, { nombre = n, como = como, accion = accion })
        end end
      end
      table.insert(d.macros, e)
    end
  end
  table.sort(d.macros, function(a, b) if a.listo ~= b.listo then return a.listo end return a.nv < b.nv end)
  return d
end
-- Clic en una macro de la vista: crearla, o decir que falta y llevarte al entrenador / a Talentos
function WowF.accionMacroVista(e)
  if not e then return end
  if #e.faltan == 0 then crearMacro(e.clave, e.cuerpo); return end
  local txt, irA, nombres = "", nil, {}
  for _, f in ipairs(e.faltan) do
    txt = txt .. "\n  " .. L("Te falta: ", "Missing: ") .. f.nombre .. " - " .. f.como
    table.insert(nombres, f.nombre)
    if f.accion == "entrenador" or not irA then irA = f.accion end
  end
  print("|cff33ccffForever Guide|r: " .. e.nombre .. txt)
  if irA == "talentos" then if WowF.abrirLibro then WowF.abrirLibro("Talentos") end
  elseif WowF.irAlEntrenador then WowF.irAlEntrenador(L("aprender ", "learn ") .. table.concat(nombres, ", ")) end
end

-- ===================== Avisos: macro nueva, macro que mejora sola, rotacion que cambia =====================
-- Al aprender hechizos o subir de nivel se compara con lo guardado para este personaje (WowFExportarDB.avisos).
-- La primera vez solo se guarda (no avisa de todo lo que ya tenias).
local function listaMacros(clase, p)
  return macrosPara(clase, p)
end
-- 16-oct: tambien los "extra" que ya sabes de cada macro lista (ext[nombre] = { hechizos }): asi se avisa
-- "Ahora tu macro X tambien usa Y" (el cuerpo no cambia al aprenderlos, por eso van aparte). Sin plan, conPlan = false.
local function estadoActual()
  local clase = claseJugador()
  local nivel = UnitLevel("player") or 1
  local macros, orden, rot, ext = {}, {}, {}, {}
  local ok, p = pcall(WowF.armarPlan or function() end)
  local conPlan = ok and p and true or false
  for _, m in ipairs(listaMacros(clase, conPlan and p or nil)) do
    local nv, faltan, extSabe = revisarMacro(clase, m, conPlan and p or nil)
    if nv and nv <= nivel and #faltan == 0 then
      macros[m[2]] = cuerpoMacro(clase, m[3]); table.insert(orden, m)
      ext[m[2]] = extSabe or {}
    end
  end
  if conPlan then
    local porClase = ROT[clase or ""] or {}
    local l = porClase[ramaAhora(p)]
    if not l then l = WowF._primeraRama(porClase) end
    for _, r in ipairs(l or {}) do if lotengo(hechizo(clase, r[1])) then table.insert(rot, r) end end
  end
  return macros, orden, rot, ext, conPlan
end
-- Hay algo de la rotacion o una macro de tu clase que llegue entre esos niveles (desde < nivel <= hasta)? (para las pruebas)
function WowF.hayAlgoNuevo(desde, hasta)
  local clase = claseJugador()
  local ok, p = pcall(WowF.armarPlan or function() end)
  for _, m in ipairs(listaMacros(clase, ok and p or nil)) do
    local nv = revisarMacro(clase, m, ok and p or nil)
    if nv and nv > desde and nv <= hasta then return true end
  end
  if not (ok and p) then return true end
  local porClase = ROT[clase or ""] or {}
  local l = porClase[ramaAhora(p)]
  if not l then l = WowF._primeraRama(porClase) end
  for _, r in ipairs(l or {}) do
    local h = hechizo(clase, r[1])
    -- un talento solo cuenta si ya lo tienes (al subir de nivel no se aprende solo: hay que poner el punto)
    local nv
    if esTalento(clase, r[1]) then nv = lotengo(h) and nivelEnPlan(p, r[1]) or nil else nv = h and h[1] end
    if nv and nv > desde and nv <= hasta then return true end
  end
  return false
end

local aviso
-- 12-oct: cada linea es una funcion (L se evalua al pintar): al cambiar de idioma el aviso abierto se reescribe
local function textosAviso(fuente)
  local l = {}
  for i, x in ipairs(fuente) do l[i] = type(x) == "function" and x() or x end
  return l
end
local function mostrarAviso(fuente, pestana)
  local lineas = textosAviso(fuente)
  for _, l in ipairs(lineas) do print("|cff33ccffForever Guide|r: " .. l) end
  -- 13-oct: con "Ventanas al subir de nivel" apagada (Ajustes), solo el chat de arriba
  if WowFExportarDB and WowFExportarDB.avisoSubirNivel == false then return end
  if not aviso then
    aviso = CreateFrame("Frame", "wowFAviso", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    aviso:SetSize(440, 130)
    aviso:SetPoint("TOP", 0, -120)
    aviso:SetFrameStrata("DIALOG")
    -- 11-oct (hibrido): cabecera pequena "Forever Guide", titulo serif y la lista en Signika
    local E = WowF.estilo
    E.marco(aviso, "aviso")
    aviso:EnableMouse(true)
    aviso.cab = E.cabecera(aviso, 20)
    aviso.cab.titulo:SetText("Forever Guide")
    aviso.titulo = E.titulo(aviso, nil, 15)
    aviso.titulo:SetPoint("TOPLEFT", 18, -36)
    aviso.texto = E.cuerpo(aviso, nil, 12)
    aviso.texto:SetPoint("TOPLEFT", 18, -60)
    aviso.texto:SetPoint("TOPRIGHT", -18, -60)
    aviso.texto:SetJustifyH("LEFT")
    if aviso.texto.SetSpacing then aviso.texto:SetSpacing(3) end
    aviso.ver = CreateFrame("Button", nil, aviso, "UIPanelButtonTemplate")
    WowF.estilo.boton(aviso.ver, "brasa")
    aviso.ver:SetSize(130, 24)
    aviso.ver:SetPoint("BOTTOM", -70, 14)
    aviso.ver:SetScript("OnClick", function() aviso:Hide(); if WowF.abrirLibro then WowF.abrirLibro(aviso.pestana) end end)
    aviso.cerrar = CreateFrame("Button", nil, aviso, "UIPanelButtonTemplate")
    WowF.estilo.boton(aviso.cerrar, "cuero")
    aviso.cerrar:SetSize(130, 24)
    aviso.cerrar:SetPoint("BOTTOM", 70, 14)
    aviso.cerrar:SetScript("OnClick", function() aviso:Hide() end)
  end
  aviso.pestana, aviso.fuente = pestana, fuente
  aviso.titulo:SetText(L("Tienes cosas nuevas", "You have new things"))
  aviso.texto:SetText(table.concat(lineas, "\n"))
  aviso:SetHeight(112 + (aviso.texto:GetStringHeight() or (16 * #lineas)))
  aviso.ver:SetText(L("Revisar", "Review"))
  aviso.cerrar:SetText(L("Cerrar", "Close"))
  -- 13-oct (Ajustes > Avisos emergentes): tamano propio y duracion elegida (nil = se queda hasta Cerrar)
  if WowF.escalaPopup then WowF.escalaPopup(aviso, "wowFAviso") end
  aviso:Show()
  local dura = 30
  if WowF.duracionPopup then dura = WowF.duracionPopup(30) end
  local hasta = (GetTime and GetTime() or 0) + (dura or 0)
  aviso.hasta = hasta
  if dura and GetTime and C_Timer and C_Timer.After then C_Timer.After(dura, function() if aviso.hasta == hasta then aviso:Hide() end end) end
  pcall(PlaySound, SOUNDKIT and SOUNDKIT.READY_CHECK or 8960)
end
WowF.alReidiomar = WowF.alReidiomar or {}
table.insert(WowF.alReidiomar, function()
  if not (aviso and aviso:IsShown() and aviso.fuente) then return end
  local lineas = textosAviso(aviso.fuente)
  aviso.titulo:SetText(L("Tienes cosas nuevas", "You have new things"))
  aviso.texto:SetText(table.concat(lineas, "\n"))
  aviso:SetHeight(112 + (aviso.texto:GetStringHeight() or (16 * #lineas)))
  aviso.ver:SetText(L("Revisar", "Review"))
  aviso.cerrar:SetText(L("Cerrar", "Close"))
end)
function WowF.cerrarAviso() if aviso then aviso:Hide() end end
function WowF.avisoTexto() -- para las pruebas
  return (aviso and aviso:IsShown() and aviso.texto:GetText()) or ""
end

local pendiente = false
local function revisarAvisos()
  pendiente = false
  if not WowFExportarDB then return end
  if InCombatLockdown and InCombatLockdown() then pendiente = true; return end -- en combate no se tocan macros
  local clase = claseJugador()
  local macros, orden, rot, ext, conPlan = estadoActual()
  -- 16-oct: sin plan no se sabe tu rama (las macros dependen de ella): no se guarda nada para no avisar de mas luego
  if not conPlan then return end
  local clave = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
  WowFExportarDB.avisos = WowFExportarDB.avisos or {}
  local antes = WowFExportarDB.avisos[clave]
  local nombresRot = {}
  for _, r in ipairs(rot) do table.insert(nombresRot, r[1]) end
  WowFExportarDB.avisos[clave] = { macros = macros, rot = nombresRot, ext = ext, ver = 2 }
  if not antes then return end
  -- 16-oct: las macros se rehicieron (nombres nuevos): lo guardado con la version vieja no cuenta como "nuevo"
  if antes.ver ~= 2 then antes.macros = macros end
  local lineas, pestana = {}, nil
  for _, m in ipairs(orden) do
    local viejo = antes.macros and antes.macros[m[2]]
    if not viejo then
      table.insert(lineas, function() return VERDE .. L("Ya puedes usar la macro ", "You can now use the macro ") .. "|r" .. ORO .. nombreMacro(m[2]) .. "|r" .. GRIS .. " - " .. L(m[4], m[5]) .. "|r" end)
      pestana = pestana or "Macros"
    else
      if viejo ~= macros[m[2]] then
        -- Que hechizo entro: el elegido en la primera {A|B} que sepas
        local usa
        for txt in m[3]:gmatch("{([^}]+)}") do
          if txt:find("|", 1, true) then local n, _, sabe = alternativa(clase, txt); if sabe then usa = n; break end end
        end
        local idx = indiceMacro(m[2])
        if idx and idx > 0 and EditMacro and pcall(EditMacro, idx, nombreMacro(m[2]), nil, macros[m[2]]) then
          table.insert(lineas, function() return CELESTE .. L("Tu macro ", "Your macro ") .. "|r" .. ORO .. nombreMacro(m[2]) .. "|r" .. CELESTE .. L(" se actualizo sola", " updated itself") .. "|r" .. (usa and (GRIS .. L(": ahora usa ", ": now uses ") .. "|r" .. BLANCO .. usa .. "|r") or "") end)
        else
          table.insert(lineas, function() return CELESTE .. L("Macro mejorada: ", "Improved macro: ") .. "|r" .. ORO .. nombreMacro(m[2]) .. "|r" .. (usa and (GRIS .. L(" (ahora usa ", " (now uses ") .. usa .. ")|r") or "") end)
        end
        pestana = pestana or "Macros"
      end
      -- 16-oct (Andy): "este poder se agrego a esta macro": un hechizo extra que acabas de aprender y la macro ya usa
      if antes.ext then
        local ya = {}
        for _, n in ipairs(antes.ext[m[2]] or {}) do ya[n] = true end
        for _, n in ipairs(ext[m[2]] or {}) do
          if not ya[n] then
            local creada = (indiceMacro(m[2]) or 0) > 0
            table.insert(lineas, function() return CELESTE .. L("Ahora tu macro ", "Your macro ") .. "|r" .. ORO .. nombreMacro(m[2]) .. "|r"
              .. CELESTE .. L(" tambien usa ", " now also uses ") .. "|r" .. BLANCO .. n .. "|r"
              .. GRIS .. (creada and L(" (ya funciona, no tienes que cambiar nada)", " (it already works, nothing to change)")
                or L("; creala en Macros", "; create it in Macros")) .. "|r" end)
            pestana = pestana or "Macros"
          end
        end
      end
    end
  end
  local viejos = {}
  for _, n in ipairs(antes.rot or {}) do viejos[n] = true end
  for _, r in ipairs(rot) do
    if not viejos[r[1]] then
      table.insert(lineas, function() return NARANJA .. L("Tu rotacion cambio: ", "Your rotation changed: ") .. "|r" .. BLANCO .. r[1] .. "|r" .. GRIS .. " - " .. L(r[2], r[3]) .. "|r" end)
      pestana = pestana or "Rotacion"
    end
  end
  if #lineas == 0 then return end
  if #lineas > 5 then
    local resto = #lineas - 4
    for i = #lineas, 5, -1 do table.remove(lineas, i) end
    table.insert(lineas, function() return GRIS .. L("y ", "and ") .. resto .. L(" cosas mas.", " more.") .. "|r" end)
  end
  table.insert(lineas, function() return GRIS .. L("Revisalo en tu plan (/wowf): pulsa Revisar.", "Check it in your plan (/wowf): press Review.") .. "|r" end)
  mostrarAviso(lineas, pestana)
  if WowF.libro and WowF.libro:IsShown() and WowF.abrirLibro then pcall(WowF.abrirLibro) end
end
WowF.revisarAvisos = revisarAvisos

local vigia = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "CHARACTER_POINTS_CHANGED", "PLAYER_REGEN_ENABLED" }) do pcall(vigia.RegisterEvent, vigia, ev) end
local programado = false
vigia:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_REGEN_ENABLED" and not pendiente then return end
  if programado then return end
  programado = true
  C_Timer.After(ev == "PLAYER_LOGIN" and 6 or 2, function() programado = false; pcall(revisarAvisos) end)
end)
