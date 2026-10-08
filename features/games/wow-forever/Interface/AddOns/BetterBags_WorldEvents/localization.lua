-- localization.lua
local L = {}

-- Localization table
L.locales = {
    ["enUS"] = {
        ["Noblegarden"] = "Noblegarden",
        ["Darkmoon Faire"] = "Darkmoon Faire",
        ["Lunar Festival"] = "Lunar Festival",
        ["Midsummer Fire Festival"] = "Midsummer Fire Festival",
        ["Remix"] = "Remix",
        ["Remix: Cache"] = "Remix: Cache",
        ["Remix: Artifact"] = "Remix: Artifact",
        ["Remix: Reputation"] = "Remix: Reputation",
        ["Remix: Buff"] = "Remix: Buff",
        ["Radiant Echoes"] = "Radiant Echoes",
        ["Brewfest"] = "Brewfest",
        ["20th Anniversary"] = "20th Anniversary",
        ["Hallow's End"] = "Hallow's End",
        ["Feast of Winter Veil"] = "Feast of Winter Veil",
        ["Love is in the Air"] = "Love is in the Air",
        ["Winds of Mysterious Fortune"] ="Winds of Mysterious Fortune",
        ["Dastardly Duos"] = "Dastardly Duos",
        ["A Greedy Emissary"] = "A Greedy Emissary",
    },
    ["frFR"] = {
        ["Noblegarden"] = "Le Jardin des nobles",
        ["Darkmoon Faire"] = "Foire de Sombrelune",
        ["Lunar Festival"] = "Fête lunaire",
        ["Midsummer Fire Festival"] = "Fête du Feu du solstice d'été",
        ["Remix"] = "Remix",
        ["Remix: Cache"] = "Remix: Cache",
        ["Remix: Artifact"] = "Remix: Arme",
        ["Remix: Reputation"] = "Remix: Réputation",
        ["Remix: Buff"] = "Remix: Amélioration",
        ["Radiant Echoes"] = "Échos radieux",
        ["Brewfest"] = "Fête des Brasseurs",
        ["20th Anniversary"] = "20e anniversaire",
        ["Hallow's End"] = "Sanssaint",
        ["Feast of Winter Veil"] = "Voile d'hiver",
        ["Love is in the Air"] = "De l'amour dans l'air",
        ["Winds of Mysterious Fortune"] ="Vents de bonne aventure mystérieuse",
        ["Dastardly Duos"] = "Duos infâmes",
        ["A Greedy Emissary"] = "Émissaire cupide",
    },
    ["deDE"] = {
        ["Noblegarden"] = "Nobelgartenfest",
        ["Darkmoon Faire"] = "Dunkelmond-Jahrmarkt",
        ["Lunar Festival"] = "Mondfest",
        ["Midsummer Fire Festival"] = "Sonnenwendfest",
        ["Remix"] = "Remix",
        ["Remix: Cache"] = "Remix: Cache",
        ["Remix: Artifact"] = "Remix: Artifact",
        ["Remix: Reputation"] = "Remix: Reputation",
        ["Remix: Buff"] = "Remix: Buff",
        ["Radiant Echoes"] = "Strahlenden Echos",
        ["Brewfest"] = "Braufest",
        ["20th Anniversary"] = "Der 20. Geburtstag",
        ["Hallow's End"] = "Schlotternechte",
        ["Feast of Winter Veil"] = "Winterhauchfest",
        ["Love is in the Air"] = "Liebe liegt in der Luft",
        ["Winds of Mysterious Fortune"] ="Winde des mysteriösen Glücks",
        ["Dastardly Duos"] = "Durchtriebene Duos",
        ["A Greedy Emissary"] = "Ein gieriger Abgesandter",
    },
    ["ptBR"] = {
        ["Noblegarden"] = "Jardinova",
        ["Darkmoon Faire"] = "Feira de Negraluna",
        ["Lunar Festival"] = "Festival da Lua",
        ["Midsummer Fire Festival"] = "Festival do Fogo do Solstício",
        ["Remix"] = "Remix",
        ["Remix: Cache"] = "Remix: Cache",
        ["Remix: Artifact"] = "Remix: Artifact",
        ["Remix: Reputation"] = "Remix: Reputation",
        ["Remix: Buff"] = "Remix: Buff",
        ["Radiant Echoes"] = "Ecos Radiantes",
        ["Brewfest"] = "CervaFest",
        ["20th Anniversary"] = "20º Aniversário",
        ["Hallow's End"] = "Noturnália",
        ["Feast of Winter Veil"] = "Festa do Véu de Inverno",
        ["Love is in the Air"] = "O Amor Está No Ar",
        ["Winds of Mysterious Fortune"] ="Ventos da Fortuna Misteriosa",
        ["Dastardly Duos"] = "Duplas da Discórdia",
        ["A Greedy Emissary"] = "Um Emissário Ganancioso",
    }
}

-- Detects current language
L.currentLocale = GetLocale()

-- Function to get the translation
function L:Get(key)
    return self.locales[self.currentLocale] and self.locales[self.currentLocale][key] or self.locales["enUS"][key]
end

-- Global L Expose
_G.L = L