PSC_DB = nil


local CLASSES_TO_ENGLISH = {
    deDE = { ["Druide"]="Druid", ["Druidin"]="Druid", ["Jäger"]="Hunter", ["Jägerin"]="Hunter", ["Magier"]="Mage", ["Magierin"]="Mage", ["Paladin"]="Paladin", ["Priester"]="Priest", ["Priesterin"]="Priest", ["Schurke"]="Rogue", ["Schurkin"]="Rogue", ["Schamane"]="Shaman", ["Schamanin"]="Shaman", ["Hexenmeister"]="Warlock", ["Hexenmeisterin"]="Warlock", ["Krieger"]="Warrior", ["Kriegerin"]="Warrior" },
    frFR = { ["Druide"]="Druid", ["Druidesse"]="Druid", ["Chasseur"]="Hunter", ["Chasseresse"]="Hunter", ["Mage"]="Mage", ["Paladin"]="Paladin", ["Paladine"]="Paladin", ["Prêtre"]="Priest", ["Prêtresse"]="Priest", ["Voleur"]="Rogue", ["Voleuse"]="Rogue", ["Chaman"]="Shaman", ["Chamane"]="Shaman", ["Démoniste"]="Warlock", ["Guerrier"]="Warrior", ["Guerrière"]="Warrior" },
    esES = { ["Druida"]="Druid", ["Cazador"]="Hunter", ["Cazadora"]="Hunter", ["Mago"]="Mage", ["Maga"]="Mage", ["Paladín"]="Paladin", ["Paladina"]="Paladin", ["Sacerdote"]="Priest", ["Sacerdotisa"]="Priest", ["Pícaro"]="Rogue", ["Pícara"]="Rogue", ["Chamán"]="Shaman", ["Chamana"]="Shaman", ["Brujo"]="Warlock", ["Bruja"]="Warlock", ["Guerrero"]="Warrior", ["Guerrera"]="Warrior" },
    esMX = { ["Druida"]="Druid", ["Cazador"]="Hunter", ["Cazadora"]="Hunter", ["Mago"]="Mage", ["Maga"]="Mage", ["Paladín"]="Paladin", ["Sacerdote"]="Priest", ["Sacerdotisa"]="Priest", ["Pícaro"]="Rogue", ["Pícara"]="Rogue", ["Chamán"]="Shaman", ["Brujo"]="Warlock", ["Bruja"]="Warlock", ["Guerrero"]="Warrior", ["Guerrera"]="Warrior" },
    ptBR = { ["Druida"]="Druid", ["Druidesa"]="Druid", ["Caçador"]="Hunter", ["Caçadora"]="Hunter", ["Mago"]="Mage", ["Maga"]="Mage", ["Paladino"]="Paladin", ["Paladina"]="Paladin", ["Sacerdote"]="Priest", ["Sacerdotisa"]="Priest", ["Ladino"]="Rogue", ["Ladina"]="Rogue", ["Xamã"]="Shaman", ["Bruxo"]="Warlock", ["Bruxa"]="Warlock", ["Guerreiro"]="Warrior", ["Guerreira"]="Warrior" },
}

local RACES_TO_ENGLISH = {
    deDE = { ["Mensch"]="Human", ["Orc"]="Orc", ["Orcin"]="Orc", ["Zwerg"]="Dwarf", ["Zwergin"]="Dwarf", ["Nachtelf"]="Night Elf", ["Nachtelfe"]="Night Elf", ["Untoter"]="Undead", ["Untote"]="Undead", ["Tauren"]="Tauren", ["Taurin"]="Tauren", ["Gnom"]="Gnome", ["Gnomin"]="Gnome", ["Troll"]="Troll", ["Trollin"]="Troll", ["Blutelf"]="Blood Elf", ["Blutelfe"]="Blood Elf", ["Draenei"]="Draenei" },
    frFR = { ["Humain"]="Human", ["Humaine"]="Human", ["Orc"]="Orc", ["Orque"]="Orc", ["Nain"]="Dwarf", ["Naine"]="Dwarf", ["Elfe de la nuit"]="Night Elf", ["Mort-vivant"]="Undead", ["Morte-vivante"]="Undead", ["Tauren"]="Tauren", ["Taurène"]="Tauren", ["Gnome"]="Gnome", ["Troll"]="Troll", ["Trollesse"]="Troll", ["Elfe de sang"]="Blood Elf", ["Draeneï"]="Draenei" },
    esES = { ["Humano"]="Human", ["Humana"]="Human", ["Orco"]="Orc", ["Orca"]="Orc", ["Enano"]="Dwarf", ["Enana"]="Dwarf", ["Elfo de la noche"]="Night Elf", ["Elfa de la noche"]="Night Elf", ["No-muerto"]="Undead", ["No-muerta"]="Undead", ["Tauren"]="Tauren", ["Gnomo"]="Gnome", ["Gnoma"]="Gnome", ["Trol"]="Troll", ["Elfo de sangre"]="Blood Elf", ["Elfa de sangre"]="Blood Elf", ["Draenei"]="Draenei" },
    esMX = { ["Humano"]="Human", ["Humana"]="Human", ["Orc"]="Orc", ["Enano"]="Dwarf", ["Elfo de la noche"]="Night Elf", ["Elfa de la noche"]="Night Elf", ["No-muerto"]="Undead", ["No-muerta"]="Undead", ["Tauren"]="Tauren", ["Gnomo"]="Gnome", ["Trol"]="Troll", ["Elfo de sangre"]="Blood Elf", ["Draenei"]="Draenei" },
    ptBR = { ["Humano"]="Human", ["Humana"]="Human", ["Orc"]="Orc", ["Orquisa"]="Orc", ["Anão"]="Dwarf", ["Elfo Noturno"]="Night Elf", ["Renegado"]="Undead", ["Morto-vivo"]="Undead", ["Morta-viva"]="Undead", ["Tauren"]="Tauren", ["Taurena"]="Tauren", ["Gnomo"]="Gnome", ["Troll"]="Troll", ["Trolesa"]="Troll", ["Elfo Sangrento"]="Blood Elf", ["Draenei"]="Draenei" },
}

-- Zone name translations (English, German, French, Spanish)
PSC_ZONE_TRANSLATIONS_CLASSIC = {
    ["Dun Morogh"] = {"Dun Morogh", "Dun Morogh", "Dun Morogh", "Dun Morogh", "Dun Morogh"},
    ["Elwynn Forest"] = {"Elwynn Forest", "Wald von Elwynn", "Forêt d'Elwynn", "Bosque de Elwynn", "Floresta de Elwynn"},
    ["Tirisfal Glades"] = {"Tirisfal Glades", "Tirisfal", "Clairières de Tirisfal", "Claros de Tirisfal", "Clareiras de Tirisfal"},
    ["Durotar"] = {"Durotar", "Durotar", "Durotar", "Durotar", "Durotar"},
    ["Westfall"] = {"Westfall", "Westfall", "Marche de l'Ouest (Westfall)", "Páramos de Poniente", "Cerro Oeste"},
    ["Loch Modan"] = {"Loch Modan", "Loch Modan", "Loch Modan", "Loch Modan", "Loch Modan"},
    ["Silverpine Forest"] = {"Silverpine Forest", "Silberwald", "Forêt des Pins argentés", "Bosque de Argénteos", "Floresta de Pinhaprata"},
    ["Redridge Mountains"] = {"Redridge Mountains", "Rotkammgebirge", "Les Carmines", "Montañas Crestagrana", "Montanhas Cristarrubra"},
    ["Duskwood"] = {"Duskwood", "Dämmerwald", "Bois de la Pénombre (Duskwood)", "Bosque del Ocaso", "Floresta do Crepúsculo"},
    ["Hillsbrad Foothills"] = {"Hillsbrad Foothills", "Vorgebirge des Hügellands", "Contreforts de Hautebrande", "Laderas de Trabalomas", "Contrafortes de Eira dos Montes"},
    ["Wetlands"] = {"Wetlands", "Sumpfland", "Les Paluns", "Los Humedales", "Pantanal"},
    ["Alterac Mountains"] = {"Alterac Mountains", "Alteracgebirge", "Montagnes d'Alterac", "Montañas de Alterac", "Montanhas de Alterac"},
    ["Arathi Highlands"] = {"Arathi Highlands", "Arathihochland", "Hautes-terres d'Arathi", "Tierras Altas de Arathi", "Planalto Arathi"},
    ["Stranglethorn Vale"] = {"Stranglethorn Vale", "Schlingendorntal", "Vallée de Strangleronce (Stranglethorn Vale)", "Vega de Tuercespina", "Selva do Espinhaço"},
    ["Badlands"] = {"Badlands", "Ödland", "Terres ingrates", "Tierras Inhóspitas", "Ermos"},
    ["Searing Gorge"] = {"Searing Gorge", "Sengende Schlucht", "Gorge des Vents brûlants (Searing Gorge)", "La Garganta de Fuego", "Garganta Abrasadora"},
    ["Burning Steppes"] = {"Burning Steppes", "Brennende Steppe", "Steppes ardentes", "Las Estepas Ardientes", "Estepes Ardentes"},
    ["Swamp of Sorrows"] = {"Swamp of Sorrows", "Sümpfe des Elends", "Marais des Chagrins", "Pantano de las Penas", "Pântano das Mágoas"},
    ["Blasted Lands"] = {"Blasted Lands", "Verwüstete Lande", "Terres foudroyées", "Las Tierras Devastadas", "Barreira do Inferno"},
    ["Western Plaguelands"] = {"Western Plaguelands", "Westliche Pestländer", "Maleterres de l'ouest", "Tierras de la Peste del Oeste", "Terras Pestilentas Ocidentais"},
    ["Eastern Plaguelands"] = {"Eastern Plaguelands", "Östliche Pestländer", "Maleterres de l'est", "Tierras de la Peste del Este", "Terras Pestilentas Orientais"},
    ["Deadwind Pass"] = {"Deadwind Pass", "Gebirgspass der Totenwinde", "Défilé de Deuillevent", "Paso de la Muerte", "Trilha do Vento Morto"},
    ["Stormwind City"] = {"Stormwind City", "Sturmwind", "Cité de Stormwind", "Ventormenta", "Ventobravo"},
    ["Mulgore"] = {"Mulgore", "Mulgore", "Mulgore", "Mulgore", "Mulgore"},
    ["Teldrassil"] = {"Teldrassil", "Teldrassil", "Teldrassil", "Teldrassil", "Teldrassil"},
    ["Darkshore"] = {"Darkshore", "Dunkelküste", "Sombrivage", "Costa Oscura", "Costa Negra"},
    ["The Barrens"] = {"The Barrens", "Brachland", "Les Tarides (the Barrens)", "Los Baldíos", "Sertões"},
    ["Stonetalon Mountains"] = {"Stonetalon Mountains", "Steinkrallengebirge", "Les Serres-Rocheuses", "Sierra Espolón", "Cordilheira das Torres de Pedra"},
    ["Ashenvale"] = {"Ashenvale", "Eschental", "Orneval", "Vallefresno", "Vale Gris"},
    ["Thousand Needles"] = {"Thousand Needles", "Tausend Nadeln", "Mille pointes", "Las Mil Agujas", "Mil Agulhas"},
    ["Desolace"] = {"Desolace", "Desolace", "Désolace", "Desolace", "Desolação"},
    ["Dustwallow Marsh"] = {"Dustwallow Marsh", "Düstermarschen", "Marécage d'Âprefange", "Marjal Revolcafango", "Pântano Vadeoso"},
    ["Feralas"] = {"Feralas", "Feralas", "Féralas", "Feralas", "Feralas"},
    ["Tanaris"] = {"Tanaris", "Tanaris", "Tanaris", "Tanaris", "Tanaris"},
    ["Azshara"] = {"Azshara", "Azshara", "Azshara", "Azshara", "Azshara"},
    ["Felwood"] = {"Felwood", "Teufelswald", "Gangrebois", "Frondavil", "Selva Maleva"},
    ["Un'Goro Crater"] = {"Un'Goro Crater", "Krater von Un'Goro", "Cratère d'Un'Goro", "Cráter de Un'Goro", "Cratera Un'Goro"},
    ["Silithus"] = {"Silithus", "Silithus", "Silithus", "Silithus", "Silithus"},
    ["Winterspring"] = {"Winterspring", "Winterquell", "Berceau-de-l'Hiver", "Cuna del Invierno", "Hibérnia"},
    ["Ironforge"] = {"Ironforge", "Eisenschmiede", "Forgefer", "Forjaz", "Altaforja"},
    ["Orgrimmar"] = {"Orgrimmar", "Orgrimmar", "Orgrimmar", "Orgrimmar", "Orgrimmar"},
    ["Thunder Bluff"] = {"Thunder Bluff", "Donnerfels", "Pitons-du-Tonnerre", "Cima del Trueno", "Penhasco do Trovão"},
    ["Darnassus"] = {"Darnassus", "Darnassus", "Darnassus", "Darnassus", "Darnassus"},
    ["Undercity"] = {"Undercity", "Unterstadt", "Fossoyeuse", "Entrañas", "Cidade Baixa"},
    ["The Hinterlands"] = {"The Hinterlands", "Hinterland", "Les Hinterlands", "Tierras del Interior", "Terras Agrestes"},
    ["Moonglade"] = {"Moonglade", "Mondlichtung", "Reflet-de-Lune", "Claro de la Luna", "Clareira da Lua"},
    ["Blackrock Mountain"] = {"Blackrock Mountain", "Der Schwarzfels", "Mont Blackrock", "Montaña Roca Negra", "Montanha Rocha Negra"},
    ["Arathi Basin"] = {"Arathi Basin", "Arathibecken", "Bassin d'Arathi", "Cuenca de Arathi", "Bacia de Arathi"},
    ["Warsong Gulch"] = {"Warsong Gulch", "Kriegshymnenschlucht", "Goulet des Chanteguerres", "Garganta Grito de Guerra", "Garganta Grito de Guerra"},
    ["Alterac Valley"] = {"Alterac Valley", "Alteractal", "Vallée d'Alterac", "Valle de Alterac", "Vale Alterac"},
    ["Wailing Caverns"] = {"Wailing Caverns", "Die Höhlen des Wehklagens", "Cavernes des Lamentations", "Cuevas de los Lamentos", "Caverna Uivante"},
    ["Blackfathom Deeps"] = {"Blackfathom Deeps", "Tiefschwarze Grotte", "Profondeurs de Brassenoire", "Cavernas de Brazanegra", "Profundezas Negras"},
    ["Deadmines"] = {"Deadmines", "Die Todesminen", "Mortemines", "Minas Mortales", "Minas Mortíferas"},
    ["Scarlet Monastery"] = {"Scarlet Monastery", "Das Scharlachrote Kloster", "Monastère écarlate", "Monasterio Escarlata", "Monastério Escarlate"},
    ["Ruins of Lordaeron"] = {"Ruins of Lordaeron", "Ruinen von Lordaeron", "Ruines de Lordaeron", "Ruinas de Lordaeron", "Ruínas de Lordaeron"},
    ["Nagrand Arena"] = {"Nagrand Arena", "Arena von Nagrand", "Arène de Nagrand", "Arena de Nagrand", "Arena de Nagrand"},
    ["Blade's Edge Arena"] = {"Blade's Edge Arena", "Arena des Schergrats", "Arène des Tranchantes", "Arena Filospada", "Arena da Lâmina Afiada"},
    ["Gurubashi Arena"] = {"Gurubashi Arena", "Arena der Gurubashi", "Arène des Gurubashi", "Arena de Gurubashi", "Arena dos Gurubashi"},
    ["The Great Arena"] = {"The Great Arena", "Die große Arena", "La Grande arène", "La Gran Arena", "A Grande Arena"},
    ["Battle Ring"] = {"Battle Ring", "Kampfring", "L'aréne", "El Ring de Batalla", "Ring de Batalha"},
}

PSC_ZONE_TRANSLATIONS_TBC = {
    ["Eversong Woods"] = {"Eversong Woods", "Immersangwald", "Bois des Chants éternels", "Bosque Canción Eterna", "Floresta do Canto Eterno"},
    ["Ghostlands"] = {"Ghostlands", "Geisterlande", "Les Terres fantômes", "Tierras Fantasma", "Terra Fantasma"},
    ["Hellfire Peninsula"] = {"Hellfire Peninsula", "Höllenfeuerhalbinsel", "Péninsule des Flammes infernales", "Península del Fuego Infernal", "Península Fogo do Inferno"},
    ["Zangarmarsh"] = {"Zangarmarsh", "Zangarmarschen", "Marécage de Zangar", "Marisma de Zangar", "Pântano Zíngaro"},
    ["Terokkar Forest"] = {"Terokkar Forest", "Wälder von Terokkar", "Forêt de Terokkar", "Bosque de Terokkar", "Mata Terokkar"},
    ["Nagrand"] = {"Nagrand", "Nagrand", "Nagrand", "Nagrand", "Nagrand"},
    ["Blade's Edge Mountains"] = {"Blade's Edge Mountains", "Schergrat", "Les Tranchantes", "Montañas Filospada", "Montanhas da Lâmina Afiada"},
    ["Netherstorm"] = {"Netherstorm", "Nethersturm", "Raz-de-Néant", "Tormenta Abisal", "Eternévoa"},
    ["Shadowmoon Valley"] = {"Shadowmoon Valley", "Schattenmondtal", "Vallée d'Ombrelune", "Valle Sombraluna", "Vale da Lua Negra"},
    ["Shattrath City"] = {"Shattrath City", "Shattrath", "Shattrath", "Ciudad de Shattrath", "Shattrath"},
    ["Silvermoon City"] = {"Silvermoon City", "Silbermond", "Lune-d'Argent", "Ciudad de Lunargenta", "Luaprata"},
    ["Azuremyst Isle"] = {"Azuremyst Isle", "Azurmythosinsel", "Île de Brume-Azur", "Isla Bruma Azur", "Ilha Névoa Lazúli"},
    ["Bloodmyst Isle"] = {"Bloodmyst Isle", "Blutmythosinsel", "Île de Brume-Sang", "Isla Bruma de Sangre", "Ilha Névoa Rubra"},
    ["Isle of Quel'Danas"] = {"Isle of Quel'Danas", "Insel von Quel'Danas", "Île de Quel'Danas", "Isla de Quel'Danas", "Ilha de Quel'Danas"},
    ["The Exodar"] = {"The Exodar", "Die Exodar", "L'Exodar", "El Exodar", "A Exodar"},
    ["Eye of the Storm"] = {"Eye of the Storm", "Auge des Sturms", "L'Œil du cyclone", "Ojo de la Tormenta", "Olho da Tormenta"},
    ["Coilfang Reservoir"] = {"Coilfang Reservoir", "Der Echsenkopf", "Réservoir de Glissecroc", "El Reservorio de Glifo", "Reservatório da Serpe"},
    ["Thrallmar Mine"] = {"Thrallmar Mine", "Thrallmarmine", "Mine de Thrallmar", "Mina de Thrallmar", "Mina do Thrallmar"},
}

local LOCALE = GetLocale()

local ZONE_TRANSLATION_LOOKUP = nil

local function BuildZoneTranslationLookup()
    local lookup = {}

    local function AddTranslations(map)
        for englishName, translations in pairs(map) do
            if type(translations) == "table" then
                for _, localizedName in ipairs(translations) do
                    if localizedName and localizedName ~= "" then
                        lookup[localizedName] = englishName
                    end
                end
            end
        end
    end

    AddTranslations(PSC_ZONE_TRANSLATIONS_CLASSIC)
    AddTranslations(PSC_ZONE_TRANSLATIONS_TBC)

    return lookup
end


local function GetHonorRank(unit)
    if not UnitPVPRank then return 0 end

    local pvpRank = UnitPVPRank(unit)

    if not pvpRank then
        return 0
    end

    if pvpRank >= 5 then
        return pvpRank - 4
    end

    return 0
end

function PSC_ConvertGenderToString(genderCode)
    if genderCode == 2 then
        return "Male"
    elseif genderCode == 3 then
        return "Female"
    else
        return "Unknown"
    end
end

local function GetPlayerInfoFromUnit(unit)
    if not UnitExists(unit) then
        return
    end

    local name = nil
    local level = nil
    local class = nil
    local race = nil
    local gender = nil
    local guildName = nil
    local guildRankName = nil
    local rank = nil

    if UnitIsPlayer(unit) then
        local playername, realm = UnitName(unit)  -- Changed from UnitName(unit) to get name with realm
        if realm then
            name = playername .. "-" .. realm
        else
            name = playername
        end
        level = UnitLevel(unit)
        class, _ = UnitClass(unit)
        class = class:sub(1, 1):upper() .. class:sub(2):lower()
        race, _ = UnitRace(unit)
        gender = PSC_ConvertGenderToString(UnitSex(unit))
        guildName, guildRankName, _ = GetGuildInfo(unit)
        if not guildName then guildName = "" end
        if not guildRankName then guildRankName = "" end
        rank = GetHonorRank(unit)
    elseif not UnitIsPlayer(unit) then
        -- Mob for testing purposes
        name = UnitName(unit)
        level = UnitLevel(unit)
        class = "Unknown"
        race = "Unknown"
        gender = "Unknown"
        guildName = ""
        guildRankName = ""
        rank = GetHonorRank(unit)
    end

    -- if PSC_Debug then
    --     print("Player info for " .. name)
    --     print("Level: " .. tostring(level))
    --     print("Class: " .. tostring(class))
    --     print("Race: " .. tostring(race))
    --     print("Gender: " .. tostring(gender))
    --     print("Guild: " .. tostring(guildName))
    --     print("Guild Rank: " .. tostring(guildRankName))
    --     print("Rank: " .. tostring(rank))
    -- end

    if not name or not level or not class or not race or not gender or not guildName or not guildRankName or not rank then
        return nil, nil, nil, nil, nil, nil, nil, nil
    end

    return name, level, class, race, gender, guildName, guildRankName, rank
end

function PSC_GetPlayerInfoKey(name, realm)
    if not realm then
        -- For backward compatibility or same realm players
        realm = PSC_RealmName
    end
    return name .. "-" .. realm
end

function PSC_GetRealmFromInfoKey(infoKey)
    if not infoKey or not string.find(infoKey, "-") then
        return PSC_RealmName
    end
    return string.match(infoKey, "%-(.+)$")
end

function PSC_GetInfoKeyFromName(playerName)
    -- Extract realm name if present in player name
    local name, realm = playerName:match("^(.+)%-(.+)$")

    if name then
        -- Player name already includes realm
        return PSC_GetPlayerInfoKey(name, realm)
    else
        -- No realm in name, use default realm
        return PSC_GetPlayerInfoKey(playerName)
    end
end

function PSC_GetPlayerInfo(playerName)
    if not playerName then return {}, nil end

    -- 1. Try direct lookup
    local infoKey = PSC_GetInfoKeyFromName(playerName)
    if PSC_DB.PlayerInfoCache[infoKey] then
        return PSC_DB.PlayerInfoCache[infoKey], infoKey
    end

    -- 2. If not found and name has no realm, try to find matches in the cache from other realms
    -- This is common when importing data from a character on a different realm
    if not string.find(playerName, "-") then
        local searchPrefix = playerName .. "-"
        for key, info in pairs(PSC_DB.PlayerInfoCache) do
            if string.sub(key, 1, #searchPrefix) == searchPrefix then
                return info, key
            end
        end
    end

    return {}, nil
end

local function Helper_MergeKillEntries(destEntry, sourceEntry)
    destEntry.kills = (destEntry.kills or 0) + (sourceEntry.kills or 0)

    -- Keep the latest timestamp
    if (sourceEntry.lastKill or 0) > (destEntry.lastKill or 0) then
        destEntry.lastKill = sourceEntry.lastKill
        -- Update specific attributes from latest kill
        destEntry.class = sourceEntry.class
        destEntry.race = sourceEntry.race
        destEntry.gender = sourceEntry.gender
        destEntry.guild = sourceEntry.guild
        destEntry.rank = sourceEntry.rank
        destEntry.zone = sourceEntry.zone
    end

    -- Merge locations
    if sourceEntry.locations then
        if not destEntry.locations then destEntry.locations = {} end
        for _, loc in ipairs(sourceEntry.locations) do
            table.insert(destEntry.locations, loc)
        end
    elseif sourceEntry.killLocations then -- Legacy field support
        if not destEntry.locations then destEntry.locations = {} end
        if not destEntry.killLocations and not destEntry.locations then destEntry.killLocations = {} end -- Keep legacy if dest is legacy

        local targetList = destEntry.locations or destEntry.killLocations
        for _, loc in ipairs(sourceEntry.killLocations) do
            table.insert(targetList, loc)
        end
    end
end

local KILL_KEY_MIGRATION_BUDGET = 250
local killMigrationState = nil

local function InitKillKeyMigrationState()
    killMigrationState = {
        charKeys = {},
        charIndex = 1,
        killKeys = nil,
        killIndex = 1,
        newKills = nil,
        count = 0,
        running = true
    }

    local characters = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters
    if characters then
        for charKey in pairs(characters) do
            table.insert(killMigrationState.charKeys, charKey)
        end
    end
end

local function ProcessKillKeyMigrationSlice()
    local characters = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters
    if not characters then
        killMigrationState = nil
        return
    end

    local processed = 0
    while processed < KILL_KEY_MIGRATION_BUDGET do
        if killMigrationState.charIndex > #killMigrationState.charKeys then
            PSC_DB.KillKeysMigrated = true
            print("[PvPStats]: Migration step 1 complete. Updated " .. killMigrationState.count .. " database entries.")
            killMigrationState = nil
            return
        end

        local charKey = killMigrationState.charKeys[killMigrationState.charIndex]
        local charData = characters[charKey]

        if not charData or not charData.Kills then
            killMigrationState.charIndex = killMigrationState.charIndex + 1
            killMigrationState.killKeys = nil
            killMigrationState.killIndex = 1
            killMigrationState.newKills = nil
        else
            if not killMigrationState.killKeys then
                killMigrationState.killKeys = {}
                for oldKey in pairs(charData.Kills) do
                    table.insert(killMigrationState.killKeys, oldKey)
                end
                killMigrationState.killIndex = 1
                killMigrationState.newKills = {}
            end

            if killMigrationState.killIndex > #killMigrationState.killKeys then
                charData.Kills = killMigrationState.newKills
                killMigrationState.charIndex = killMigrationState.charIndex + 1
                killMigrationState.killKeys = nil
                killMigrationState.killIndex = 1
                killMigrationState.newKills = nil
            else
                local oldKey = killMigrationState.killKeys[killMigrationState.killIndex]
                killMigrationState.killIndex = killMigrationState.killIndex + 1

                local killEntry = charData.Kills[oldKey]
                local name = string.match(oldKey, "(.-)%:")
                local level = string.match(oldKey, ":(%d+)")

                if name and level then
                    local infoKey
                    local _, existingInfoKey = PSC_GetPlayerInfo(name)

                    if existingInfoKey then
                        infoKey = existingInfoKey
                    else
                        infoKey = PSC_GetInfoKeyFromName(name)
                    end

                    local newKey = infoKey .. ":" .. level

                    if newKey ~= oldKey then
                        if killMigrationState.newKills[newKey] then
                            Helper_MergeKillEntries(killMigrationState.newKills[newKey], killEntry)
                        else
                            killMigrationState.newKills[newKey] = killEntry
                        end
                        killMigrationState.count = killMigrationState.count + 1
                    else
                        if killMigrationState.newKills[oldKey] then
                            Helper_MergeKillEntries(killMigrationState.newKills[oldKey], killEntry)
                        else
                            killMigrationState.newKills[oldKey] = killEntry
                        end
                    end
                else
                    killMigrationState.newKills[oldKey] = killEntry
                end

                processed = processed + 1
            end
        end
    end

    C_Timer.After(0, ProcessKillKeyMigrationSlice)
end

function PSC_MigrateKillKeys()
    if PSC_DB.KillKeysMigrated then return end
    if killMigrationState and killMigrationState.running then return end
    print("[PvPStats]: Performing database update, this will cause your game to stutter for a few seconds...")
    InitKillKeyMigrationState()
    C_Timer.After(0, ProcessKillKeyMigrationSlice)
end

local function Helper_MergeDeathEntries(destEntry, sourceEntry)
    destEntry.deaths = (destEntry.deaths or 0) + (sourceEntry.deaths or 0)
    destEntry.assistKills = (destEntry.assistKills or 0) + (sourceEntry.assistKills or 0)
    destEntry.soloKills = (destEntry.soloKills or 0) + (sourceEntry.soloKills or 0)

    if (sourceEntry.lastDeath or 0) > (destEntry.lastDeath or 0) then
        destEntry.lastDeath = sourceEntry.lastDeath
        destEntry.zone = sourceEntry.zone
    end

    if sourceEntry.deathLocations then
        if not destEntry.deathLocations then destEntry.deathLocations = {} end
        for _, loc in ipairs(sourceEntry.deathLocations) do
            table.insert(destEntry.deathLocations, loc)
        end
    end
end

local LOSS_KEY_MIGRATION_BUDGET = 250
local lossMigrationState = nil

local function InitLossKeyMigrationState()
    lossMigrationState = {
        charKeys = {},
        charIndex = 1,
        deathKeys = nil,
        deathIndex = 1,
        newDeaths = nil,
        count = 0,
        running = true
    }

    if PSC_DB.PvPLossCounts then
        for charKey in pairs(PSC_DB.PvPLossCounts) do
            table.insert(lossMigrationState.charKeys, charKey)
        end
    end
end

local function ProcessLossKeyMigrationSlice()
    if not PSC_DB.PvPLossCounts then
        lossMigrationState = nil
        return
    end

    local processed = 0
    while processed < LOSS_KEY_MIGRATION_BUDGET do
        if lossMigrationState.charIndex > #lossMigrationState.charKeys then
            PSC_DB.LossKeysMigrated_v3 = true
            print("[PvPStats]: Death history migration complete. Normalized " .. lossMigrationState.count .. " database entries.")
            lossMigrationState = nil
            return
        end

        local charKey = lossMigrationState.charKeys[lossMigrationState.charIndex]
        local charData = PSC_DB.PvPLossCounts[charKey]

        if not charData or not charData.Deaths then
            lossMigrationState.charIndex = lossMigrationState.charIndex + 1
            lossMigrationState.deathKeys = nil
            lossMigrationState.deathIndex = 1
            lossMigrationState.newDeaths = nil
        else
            if not lossMigrationState.deathKeys then
                lossMigrationState.deathKeys = {}
                for oldName in pairs(charData.Deaths) do
                    table.insert(lossMigrationState.deathKeys, oldName)
                end
                lossMigrationState.deathIndex = 1
                lossMigrationState.newDeaths = {}
            end

            if lossMigrationState.deathIndex > #lossMigrationState.deathKeys then
                charData.Deaths = lossMigrationState.newDeaths
                lossMigrationState.charIndex = lossMigrationState.charIndex + 1
                lossMigrationState.deathKeys = nil
                lossMigrationState.deathIndex = 1
                lossMigrationState.newDeaths = nil
            else
                local oldName = lossMigrationState.deathKeys[lossMigrationState.deathIndex]
                lossMigrationState.deathIndex = lossMigrationState.deathIndex + 1

                local deathEntry = charData.Deaths[oldName]
                if deathEntry and deathEntry.deathLocations then
                    for _, loc in ipairs(deathEntry.deathLocations) do
                        if loc.assisters then
                            for _, assister in ipairs(loc.assisters) do
                                local aName = assister.name
                                if aName and string.find(aName, "-") == nil then
                                    local _, existingInfoKey = PSC_GetPlayerInfo(aName)
                                    if existingInfoKey then
                                        assister.name = existingInfoKey
                                    else
                                        assister.name = PSC_GetInfoKeyFromName(aName)
                                    end
                                end
                            end
                        end
                    end
                end

                local hasRealm = string.find(oldName, "-") ~= nil
                local newName = oldName
                if not hasRealm then
                    local _, existingInfoKey = PSC_GetPlayerInfo(oldName)
                    if existingInfoKey then
                        newName = existingInfoKey
                    else
                        newName = PSC_GetInfoKeyFromName(oldName)
                    end
                end

                if newName ~= oldName then
                    if lossMigrationState.newDeaths[newName] then
                        Helper_MergeDeathEntries(lossMigrationState.newDeaths[newName], deathEntry)
                    else
                        lossMigrationState.newDeaths[newName] = deathEntry
                    end
                    lossMigrationState.count = lossMigrationState.count + 1
                else
                    if lossMigrationState.newDeaths[oldName] then
                        Helper_MergeDeathEntries(lossMigrationState.newDeaths[oldName], deathEntry)
                    else
                        lossMigrationState.newDeaths[oldName] = deathEntry
                    end
                end

                processed = processed + 1
            end
        end
    end

    C_Timer.After(0, ProcessLossKeyMigrationSlice)
end

function PSC_MigrateLossKeys()
    if PSC_DB.LossKeysMigrated_v3 then return end
    if lossMigrationState and lossMigrationState.running then return end
    if not PSC_DB.PvPLossCounts then return end
    InitLossKeyMigrationState()
    print("[PvPStats]: Migrating death history to normalize player names...")
    C_Timer.After(0, ProcessLossKeyMigrationSlice)
end

-- Migration: level-70 kills/deaths recorded with empty/unknown zone because the
-- arena zone could not be captured at event time (bug). Assigns a random TBC arena
-- name and synthesises missing deathLocations entries where needed.
function PSC_MigrateArenaZones()
    if PSC_DB.ArenaZonesMigrated_v1 then return end

    local TBC_ARENAS = {
        "Ruins of Lordaeron",
        "Nagrand Arena",
        "Blade's Edge Arena",
    }

    local function randomArena()
        return TBC_ARENAS[math.random(1, #TBC_ARENAS)]
    end

    local function isUnknownZone(zone)
        return zone == nil or zone == "" or zone == "Unknown"
    end

    local migratedKills  = 0
    local migratedDeaths = 0

    -- ── Kills ────────────────────────────────────────────────────────────────
    if PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters then
        for _, charData in pairs(PSC_DB.PlayerKillCounts.Characters) do
            if charData.Kills then
                for killKey, killEntry in pairs(charData.Kills) do
                    local level = tonumber(string.match(killKey, ":(-?%d+)$"))
                    if level == 70 then
                        local locations = killEntry.killLocations
                        if not locations or #locations == 0 then
                            killEntry.killLocations = {
                                { timestamp = killEntry.lastKill or 0, zone = randomArena() }
                            }
                            migratedKills = migratedKills + 1
                        else
                            for _, loc in ipairs(locations) do
                                if isUnknownZone(loc.zone) then
                                    loc.zone = randomArena()
                                    migratedKills = migratedKills + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- ── Deaths & Assists ─────────────────────────────────────────────────────
    if PSC_DB.PvPLossCounts then
        for _, charLossData in pairs(PSC_DB.PvPLossCounts) do
            if charLossData.Deaths then
                for killerName, deathData in pairs(charLossData.Deaths) do
                    -- Look up killer level from PlayerInfoCache.
                    -- killerName may be stored without a realm (e.g. "Cogwhisper"),
                    -- so fall back to a prefix search when the direct lookup misses.
                    local killerLevel = -1
                    if PSC_DB.PlayerInfoCache then
                        local info = PSC_DB.PlayerInfoCache[killerName]
                        if not info then
                            -- Try prefix search ("Cogwhisper" -> "Cogwhisper-Spineshatter")
                            local prefix = killerName .. "-"
                            for cacheKey, cacheInfo in pairs(PSC_DB.PlayerInfoCache) do
                                if string.sub(cacheKey, 1, #prefix) == prefix then
                                    info = cacheInfo
                                    break
                                end
                            end
                        end
                        if info then
                            killerLevel = info.level or -1
                        end
                    end

                    if not deathData.deathLocations or #deathData.deathLocations == 0 then
                        -- deathLocations is empty – synthesise entries for level-70 killers
                        if killerLevel == 70 then
                            local zone = (not isUnknownZone(deathData.zone)) and deathData.zone or randomArena()
                            deathData.zone = zone
                            deathData.deathLocations = {}
                            for _ = 1, (deathData.deaths or 1) do
                                table.insert(deathData.deathLocations, {
                                    timestamp   = deathData.lastDeath or 0,
                                    zone        = zone,
                                    killerLevel = killerLevel,
                                })
                            end
                            migratedDeaths = migratedDeaths + 1
                        end
                    else
                        -- Fix individual location entries with unknown zone
                        for _, loc in ipairs(deathData.deathLocations) do
                            if isUnknownZone(loc.zone) then
                                local locKillerIs70 = (loc.killerLevel == 70)
                                local assisterIs70  = false
                                if not locKillerIs70 and loc.assisters then
                                    for _, assister in ipairs(loc.assisters) do
                                        if assister.level == 70 then
                                            assisterIs70 = true
                                            break
                                        end
                                    end
                                end
                                if locKillerIs70 or assisterIs70 then
                                    loc.zone = randomArena()
                                    migratedDeaths = migratedDeaths + 1
                                end
                            end
                        end

                        -- Fix top-level summary zone field
                        if isUnknownZone(deathData.zone) and killerLevel == 70 then
                            deathData.zone = randomArena()
                        end
                    end
                end
            end
        end
    end

    PSC_DB.ArenaZonesMigrated_v1 = true
    if migratedKills > 0 or migratedDeaths > 0 then
        print(string.format("[PvPStats]: Arena zone migration complete. Fixed %d kill location(s) and %d death record(s).",
            migratedKills, migratedDeaths))
    end
end

function PSC_MigratePlayerInfoCache()
    if not PSC_DB.PlayerInfoCacheMigrated then
        print("[PvPStats]: Migrating player cache to support cross-realm players...")

        local oldCache = PSC_DB.PlayerInfoCache
        local newCache = {}

        -- Migrate existing entries to the new format with realm names
        for name, data in pairs(oldCache) do
            -- Only process entries that don't already have realm name format
            if not string.find(name, "-") then
                local infoKey = PSC_GetPlayerInfoKey(name)
                newCache[infoKey] = data
            else
                -- If it already has a dash, keep it as is (shouldn't happen in current data)
                newCache[name] = data
            end
        end

        -- Replace the old cache with the new one
        PSC_DB.PlayerInfoCache = newCache
        PSC_DB.PlayerInfoCacheMigrated = true

        print("[PvPStats]: Player cache migration complete!")
    end
end

function PSC_ConvertClassToEnglish(localizedClass)
    if not localizedClass then return "Unknown" end

    if LOCALE == "enUS" or not CLASSES_TO_ENGLISH[LOCALE] then
        return localizedClass
    end

    return CLASSES_TO_ENGLISH[LOCALE][localizedClass] or localizedClass
end

function PSC_ConvertRaceToEnglish(localizedRace)
    if not localizedRace then return "Unknown" end

    if LOCALE == "enUS" or not RACES_TO_ENGLISH[LOCALE] then
        return localizedRace
    end

    return RACES_TO_ENGLISH[LOCALE][localizedRace] or localizedRace
end

function PSC_ConvertZoneToEnglish(localizedZone)
    if not localizedZone or localizedZone == "" then
        return localizedZone
    end

    if not ZONE_TRANSLATION_LOOKUP then
        ZONE_TRANSLATION_LOOKUP = BuildZoneTranslationLookup()
    end

    return ZONE_TRANSLATION_LOOKUP[localizedZone] or localizedZone
end

local function NormalizeAddonVersion(version)
    if version == nil then
        return nil
    end
    return tostring(version):gsub("^v", "")
end

function PSC_CompareAddonVersions(v1, v2)
    if v1 == v2 then return 0 end
    if not v1 then return -1 end
    if not v2 then return 1 end

    v1 = NormalizeAddonVersion(v1)
    v2 = NormalizeAddonVersion(v2)

    local parts1 = { strsplit(".", v1) }
    local parts2 = { strsplit(".", v2) }
    local maxParts = math.max(#parts1, #parts2)

    for i = 1, maxParts do
        local p1 = tonumber(parts1[i]) or 0
        local p2 = tonumber(parts2[i]) or 0
        if p1 ~= p2 then
            return (p1 < p2) and -1 or 1
        end
    end

    return 0
end

function PSC_IsAddonVersionNewer(remoteVersion, localVersion)
    local currentVersion = localVersion
    if currentVersion == nil and PSC_GetAddonVersion then
        currentVersion = PSC_GetAddonVersion()
    end

    if not remoteVersion or remoteVersion == "" then
        return false
    end

    return PSC_CompareAddonVersions(remoteVersion, currentVersion) > 0
end

function PSC_ShowAddonUpdatePopup(remoteVersion)
    if not remoteVersion or remoteVersion == "" then
        return
    end

    if PSC_DB and PSC_DB.LastAddonUpdateNotificationVersion then
        if PSC_CompareAddonVersions(remoteVersion, PSC_DB.LastAddonUpdateNotificationVersion) <= 0 then
            return
        end
    end

    if not StaticPopupDialogs["PSC_ADDON_UPDATE_AVAILABLE"] then
        StaticPopupDialogs["PSC_ADDON_UPDATE_AVAILABLE"] = {
            text = "",
            button1 = "OK",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopupDialogs["PSC_ADDON_UPDATE_AVAILABLE"].text =
        "A newer version " .. remoteVersion .. " of PvP Stats is available. You can download it from CurseForge."

    StaticPopup_Show("PSC_ADDON_UPDATE_AVAILABLE")

    if PSC_DB then
        PSC_DB.LastAddonUpdateNotificationVersion = remoteVersion
    end
end

function PSC_MigratePlayerInfoToEnglish(force)
    if not PSC_DB.PlayerInfoEnglishMigrated or force then
        for _, data in pairs(PSC_DB.PlayerInfoCache) do
            if data.class then
                local englishClass = data.class

                for locale, translations in pairs(CLASSES_TO_ENGLISH) do
                    if translations[data.class] then
                        englishClass = translations[data.class]
                        break
                    end
                end

                if englishClass ~= data.class then
                    data.class = englishClass
                end
            end

            if data.race then
                local englishRace = data.race

                for locale, translations in pairs(RACES_TO_ENGLISH) do
                    if translations[data.race] then
                        englishRace = translations[data.race]
                        break
                    end
                end

                if englishRace ~= data.race then
                    data.race = englishRace
                end
            end
        end

        local function NormalizeLocationZones(locations)
            if not locations then return end
            for _, loc in ipairs(locations) do
                if loc.zone then
                    loc.zone = PSC_ConvertZoneToEnglish(loc.zone)
                end
            end
        end

        if PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters then
            for _, charData in pairs(PSC_DB.PlayerKillCounts.Characters) do
                if charData.Kills then
                    for _, killData in pairs(charData.Kills) do
                        if killData.zone then
                            killData.zone = PSC_ConvertZoneToEnglish(killData.zone)
                        end
                        NormalizeLocationZones(killData.killLocations)
                        NormalizeLocationZones(killData.locations)
                    end
                end
            end
        end

        if PSC_DB.PvPLossCounts then
            for _, lossData in pairs(PSC_DB.PvPLossCounts) do
                if lossData.Deaths then
                    for _, deathData in pairs(lossData.Deaths) do
                        if deathData.zone then
                            deathData.zone = PSC_ConvertZoneToEnglish(deathData.zone)
                        end
                        NormalizeLocationZones(deathData.deathLocations)
                    end
                end
            end
        end

        PSC_DB.PlayerInfoEnglishMigrated = true
        print("[PvPStats]: Data migration to English complete!")
    end
end

function PSC_StorePlayerInfo(name, level, class, race, gender, guildName, guildRankName, rank)
    local playerName, playerRealm = name:match("^(.+)%-(.+)$")

    local realm
    if playerName then
        name = playerName
        realm = playerRealm
    else
        -- Otherwise use current realm
        realm = PSC_RealmName
    end

    local playerNameWithRealm = PSC_GetPlayerInfoKey(name, realm)

    if not PSC_DB.PlayerInfoCache[playerNameWithRealm] then
        PSC_DB.PlayerInfoCache[playerNameWithRealm] = {}
    end

    PSC_DB.PlayerInfoCache[playerNameWithRealm].level = level
    PSC_DB.PlayerInfoCache[playerNameWithRealm].class = class
    PSC_DB.PlayerInfoCache[playerNameWithRealm].race = race
    PSC_DB.PlayerInfoCache[playerNameWithRealm].gender = gender
    PSC_DB.PlayerInfoCache[playerNameWithRealm].guild = guildName
    PSC_DB.PlayerInfoCache[playerNameWithRealm].guildRank = guildRankName
    PSC_DB.PlayerInfoCache[playerNameWithRealm].rank = rank

    -- if PSC_Debug then
    --     print("Stored player info: " .. playerNameWithRealm .. " (" .. level .. " " .. race .. " " .. gender .. " " .. class .. ") in guild " .. guildName .. " rank " .. rank)
    -- end
end

function PSC_GetAndStorePlayerInfoFromUnit(unit, allowFriendly)
    if not UnitIsPlayer(unit) then
        return
    end

    if not allowFriendly and UnitIsFriend("player", unit) then
        return
    end
    local name, level, class, race, gender, guildName, guildRankName, rank = GetPlayerInfoFromUnit(unit)
    if not name or not level or not class or not race or not gender or not guildName or not guildRankName or not rank then
        if PSC_Debug then
            print("Incomplete player info for unit: " .. unit)
        end
        return
    end
    class = PSC_ConvertClassToEnglish(class)
    race = PSC_ConvertRaceToEnglish(race)
    PSC_StorePlayerInfo(name, level, class, race, gender, guildName, guildRankName, rank)
end


function GetRealmNameFromCharacterKey(characterKey)
    local playerRealm = characterKey:match("%-([^-]+)$")
    return playerRealm
end


local function GetPlayerInfoCacheKeyFromCharacterKeyAndEnemyPlayerName(characterKey, enemyPlayerName)
    local parsedName, parsedRealm = enemyPlayerName:match("^([^-]+)-([^-]+)$")

    if parsedRealm then
        -- enemyPlayerName already includes a realm (e.g., "Player-SomeRealm")
        -- This is assumed to be the correct and complete key.
        return enemyPlayerName
    else
        -- enemyPlayerName is just a name (e.g., "Player"), use the characterKey's realm as context.
        local characterContextRealm = GetRealmNameFromCharacterKey(characterKey)
        if not characterContextRealm then
            characterContextRealm = PSC_RealmName -- Fallback
        end
        return enemyPlayerName .. "-" .. characterContextRealm
    end
end


function PSC_CleanupPlayerInfoCache()
    if not PSC_DB.PlayerKillCounts.Characters then return end

    local cleanedInfoCache = {}
    local playersToKeep = {}

    -- Collect names of all players who have been killed by us
    for characterKey, characterData in pairs(PSC_DB.PlayerKillCounts.Characters) do
        -- Keep player info entries for all own characters on this account.
        playersToKeep[characterKey] = true
        for nameWithLevel, killData in pairs(characterData.Kills) do
            if killData.kills and killData.kills > 0 then
                local name = nameWithLevel:match("([^:]+)")
                if name then
                    local killedPlayerNameWithRealm = GetPlayerInfoCacheKeyFromCharacterKeyAndEnemyPlayerName(characterKey, name)
                    playersToKeep[killedPlayerNameWithRealm] = true
                end
            end
        end
    end

    -- Also collect names of all players who have killed us
    for characterKey, lossData in pairs(PSC_DB.PvPLossCounts) do
        if lossData.Deaths then
            for killerName, deathData in pairs(lossData.Deaths) do
                if deathData.deaths and deathData.deaths > 0 then
                    local killerNameWithRealm = GetPlayerInfoCacheKeyFromCharacterKeyAndEnemyPlayerName(characterKey, killerName)
                    playersToKeep[killerNameWithRealm] = true

                    -- Also keep info for players who have assisted in killing us
                    if deathData.deathLocations then
                        for _, location in ipairs(deathData.deathLocations) do
                            if location.assisters then
                                for _, assister in ipairs(location.assisters) do
                                    if assister.name then
                                        local assisterNameWithRealm = GetPlayerInfoCacheKeyFromCharacterKeyAndEnemyPlayerName(characterKey, assister.name)
                                        playersToKeep[assisterNameWithRealm] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Only keep info for relevant players
    for infoKey, data in pairs(PSC_DB.PlayerInfoCache) do
        if playersToKeep[infoKey] then
            cleanedInfoCache[infoKey] = data
        end
    end

    PSC_DB.PlayerInfoCache = cleanedInfoCache
end


function PSC_InitializeAchievementDataStructure()
    if not PSC_DB.CharacterAchievements then
        PSC_DB.CharacterAchievements = {}
    end

    if not PSC_DB.CharacterAchievementPoints then
        PSC_DB.CharacterAchievementPoints = {}
    end

    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB.CharacterAchievements[characterKey] then
        PSC_DB.CharacterAchievements[characterKey] = {}
    end

    if not PSC_DB.CharacterAchievementPoints[characterKey] == nil then
        PSC_DB.CharacterAchievementPoints[characterKey] = 0
    end
end


function PSC_SaveAchievement(achievementID, completedDate, points)
    if not PSC_DB.CharacterAchievements then
        PSC_InitializeAchievementDataStructure()
    end

    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB.CharacterAchievements[characterKey] then
        PSC_DB.CharacterAchievements[characterKey] = {}
    end

    if not PSC_DB.CharacterAchievements[characterKey][achievementID] then
        PSC_DB.CharacterAchievements[characterKey][achievementID] = {}
    end

    PSC_DB.CharacterAchievements[characterKey][achievementID].unlocked = true
    PSC_DB.CharacterAchievements[characterKey][achievementID].completedDate = completedDate
    PSC_DB.CharacterAchievements[characterKey][achievementID].points = points or 0

    -- Recalculate total points
    PSC_UpdateTotalAchievementPoints()
end

-- Calculate total achievement points for the current character
function PSC_UpdateTotalAchievementPoints()
    local characterKey = PSC_GetCharacterKey()
    local totalPoints = 0

    if not PSC_DB.CharacterAchievements or not PSC_DB.CharacterAchievements[characterKey] then
        PSC_DB.CharacterAchievementPoints[characterKey] = 0
        return 0
    end

    for achievementID, achievementData in pairs(PSC_DB.CharacterAchievements[characterKey]) do
        if achievementData.unlocked and achievementData.points then
            totalPoints = totalPoints + achievementData.points
        end
    end

    PSC_DB.CharacterAchievementPoints[characterKey] = totalPoints
    return totalPoints
end

function PSC_LoadDefaultSettings()
    PSC_DB.EnableKillAnnounceMessages = true
    PSC_DB.IncludePlayerDetailsInAnnounce = false
    PSC_DB.IncludeGuildDetailsInAnnounce = false
    PSC_DB.EnableRecordAnnounceMessages = true
    PSC_DB.EnableMultiKillAnnounceMessages = true
    PSC_DB.EnableHighLevelDeathWarning = true
    PSC_DB.MultiKillThreshold = 3
    PSC_DB.AnnounceChannel = "GROUP"

    PSC_DB.AutoBattlegroundMode = true
    PSC_DB.CountAssistsInBattlegrounds = true
    PSC_DB.ForceBattlegroundMode = false
    PSC_DB.CountKillsInBattlegrounds = true
    PSC_DB.CountDeathsInBattlegrounds = true

    PSC_DB.ShowKillMilestones = true
    PSC_DB.EnableKillMilestoneSound = true
    PSC_DB.ShowMilestoneForFirstKill = true
    PSC_DB.KillMilestoneInterval = 5
    PSC_DB.KillMilestoneAutoHideTime = 5
    PSC_DB.MilestoneFramePosition = {
        point="TOP",
        relativePoint="TOP",
        xOfs=0,
        yOfs=-100
    }

    -- Add default position for kill streak milestone frame
    PSC_DB.KillStreakMilestoneFramePosition = {
        point="TOP",
        relativePoint="TOP",
        xOfs=0,
        yOfs=-10
    }

    PSC_DB.EnableMultiKillSounds = true
    PSC_DB.SoundPack = "LoL"
    PSC_DB.EnableDeathSounds = false
    PSC_DB.EnableSingleKillSounds = false
    PSC_DB.EnableKillStreakSoundsAndEmotes = true
    PSC_DB.ShowScoreInPlayerTooltip = true
    PSC_DB.ShowExtendedTooltipInfo = true
    PSC_DB.ShowAccountWideStats = false
    PSC_DB.ShowOwnAltsOnLeaderboard = true
    PSC_DB.CapAchievementProgress = true

    PSC_DB.KillAnnounceMessage = "Enemyplayername killed! x#"
    PSC_DB.KillStreakEndedMessage = "My kill streak of STREAKCOUNT has ended!"
    PSC_DB.NewKillStreakRecordMessage = "New personal best: Kill streak of STREAKCOUNT!"
    PSC_DB.NewMultiKillRecordMessage = "New personal best: MULTIKILLTEXT!"

    -- Kill Streak Popup Settings
    PSC_DB.AutoOpenKillStreakPopup = false
    PSC_DB.KillStreakPopupPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        xOfs = 0,
        yOfs = 0
    }

    PSC_InitializeAchievementDataStructure()
    PSC_InitializeLeaderboardCache()
end

function PSC_InitializePlayerKillCounts()
    if not PSC_DB.PlayerKillCounts.Characters then
        PSC_DB.PlayerKillCounts.Characters = {}
    end

    -- Ensure all characters have required fields (sanity check for migration/updates)
    for key, data in pairs(PSC_DB.PlayerKillCounts.Characters) do
        if data.HighestKillStreak == nil then data.HighestKillStreak = 0 end
        if data.HighestMultiKill == nil then data.HighestMultiKill = 0 end
        if data.MultiKillCounts == nil then data.MultiKillCounts = {} end
        if data.CurrentKillStreak == nil then data.CurrentKillStreak = 0 end
        if data.Kills == nil then data.Kills = {} end
    end

    local characterKey = PSC_GetCharacterKey()
    if not PSC_DB.PlayerKillCounts.Characters[characterKey] then
        PSC_DB.PlayerKillCounts.Characters[characterKey] = {
            Kills = {},
            CurrentKillStreak = 0,
            HighestKillStreak = 0,
            HighestMultiKill = 0,
            MultiKillCounts = {},
            GrayKillsCount = nil, -- We'll set this to nil initially to detect first run
            SpawnCamperMaxKills = nil, -- Pre-calculated spawn camper achievement value
            Level1KillTimestamps = {}, -- Cached list of all level 1 kill timestamps for efficient sliding window
            CurrentKillStreakPlayers = {} -- Track players killed in current streak
        }
    end

    -- Initialize Level1KillTimestamps if it doesn't exist (backward compatibility)
    if PSC_DB.PlayerKillCounts.Characters[characterKey].Level1KillTimestamps == nil then
        PSC_DB.PlayerKillCounts.Characters[characterKey].Level1KillTimestamps = {}
    end

    -- Initialize CurrentKillStreakPlayers if it doesn't exist (for existing saves)
    if PSC_DB.PlayerKillCounts.Characters[characterKey].CurrentKillStreakPlayers == nil then
        PSC_DB.PlayerKillCounts.Characters[characterKey].CurrentKillStreakPlayers = {}
    end

    -- Initialize new kill streak popup settings if they don't exist (backward compatibility)
    if PSC_DB.AutoOpenKillStreakPopup == nil then
        PSC_DB.AutoOpenKillStreakPopup = false
    end
    if PSC_DB.KillStreakPopupPosition == nil then
        PSC_DB.KillStreakPopupPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            xOfs = 0,
            yOfs = 0
        }
    end
    if PSC_DB.IncludePlayerDetailsInAnnounce == nil then
        PSC_DB.IncludePlayerDetailsInAnnounce = false
    end
    if PSC_DB.IncludeGuildDetailsInAnnounce == nil then
        PSC_DB.IncludeGuildDetailsInAnnounce = false
    end
    if PSC_DB.ShowOwnAltsOnLeaderboard == nil then
        PSC_DB.ShowOwnAltsOnLeaderboard = true
    end
    if PSC_DB.EnableKillStreakSoundsAndEmotes == nil then
        PSC_DB.EnableKillStreakSoundsAndEmotes = true
    end
end

function PSC_InitializePlayerLossCounts()
    if not PSC_DB.PvPLossCounts then
        PSC_DB.PvPLossCounts = {}
    end

    local characterKey = PSC_GetCharacterKey()
    if not PSC_DB.PvPLossCounts[characterKey] then
        PSC_DB.PvPLossCounts[characterKey] = {
            Deaths = {}
        }
    end
end

function PSC_InitializeLeaderboardCache()
    if not PSC_DB.LeaderboardCache then
        PSC_DB.LeaderboardCache = {}
    end
end

function ResetAllStatsToDefault()
    PSC_DB.PlayerInfoCache = {}
    PSC_DB.PlayerKillCounts = {}
    PSC_DB.PvPLossCounts = {}
    PSC_DB.CharacterAchievements = {}
    PSC_DB.CharacterAchievementPoints = {}
    PSC_DB.LeaderboardCache = {}

    PSC_InitializePlayerKillCounts()
    PSC_InitializePlayerLossCounts()
    PSC_InitializeAchievementDataStructure()
    PSC_InitializeLeaderboardCache()

    print("[PvPStats]: All statistics have been reset!")
end
