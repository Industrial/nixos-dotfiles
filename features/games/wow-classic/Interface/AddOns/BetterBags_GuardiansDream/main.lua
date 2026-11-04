---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

-- Localization table
local locales = {
    ["enUS"] = {
        ["Guardians of the Dream"] = "Guardians of the Dream",
    },
    ["frFR"] = {
        ["Guardians of the Dream"] = "Gardiens du Rêve",
    },
    ["deDE"] = {
        ["Guardians of the Dream"] = "Wächter des Traums",
    },
    ["esES"] = {
        ["Guardians of the Dream"] = "Guardianes del Sueño",
    },
    ["itIT"] = {
        ["Guardians of the Dream"] = "Guardiani del Sogno",
    },
    ["ptBR"] = {
        ["Guardians of the Dream"] = "Guardiões do Sonho",
    }
}

-- Detects current language
local currentLocale = GetLocale()

-- Function to get the translation
local function L(key)
    return locales[currentLocale] and locales[currentLocale][key] or locales["enUS"][key]
end

--Dreamseeds
local Dreamseeds = {
    208066, --Small Dreamseed
    208067, --Plump Dreamseed 
    208047 --Gigantic Dreamseed
}
--Currencies
local Currencies = {
    211376, --Seedbloom
    210254, --Dreamsurge Cocoon
    210776 --Lesser Dream Infusion
}

--Containers
local Containers = {
    210872, --Satchel of Dreams
    211414, --Blossoming Dreamtrove
    211389, --Cache of Overblooming Treasures
    210992 --Overflowing Dream Warden Trove
}

local allItems = {
    Dreamseeds,
    Currencies,
    Containers
}

--Delete category before adding translations
categories:DeleteCategory("Guardians of the Dream") 

--Loop
for _, itemList in pairs(allItems) do
    for _, ItemID in pairs(itemList) do
        categories:AddItemToCategory(ItemID, L("Guardians of the Dream"))
    end
end
