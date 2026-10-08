if(GetLocale() ~= 'deDE') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "Niedriger iLvl";
L["OPTIONS_DESC"] = "Wähle den iLvl-Schwellenwert für diese Kategorie (alle Gegenstände mit einem iLvl, der strikt unter diesem Wert liegt, werden in diese Kategorie einsortiert). Nach einer Änderung des Werts kann ein UI-Reload erforderlich sein.";
L["OPTIONS_INCLUDE_JUNK"] = "Gegenstände schlechter Qualität in diese Kategorie einbeziehen";
L["OPTIONS_REFRESH"] = "UI neu laden";
L["OPTIONS_RESET_DEFAULT"] = "Auf Standardwert zurücksetzen";
L["OPTIONS_THRESHOLD"] = "iLvl-Schwellenwert (Standard: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Bitte gib eine gültige Zahl für den iLvl-Schwellenwert ein.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Einen dynamischen Schwellenwert basierend auf deinem durchschnittlichen angelegten iLvl verwenden";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Einen dynamischen Schwellenwert basierend auf deinem durchschnittlichen angelegten iLvl verwenden (aktuell: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "Wenn aktiviert, wird der iLvl-Schwellenwert automatisch anhand deines durchschnittlichen angelegten Gegenstandslevels berechnet. Er wird bei jeder Änderung dieser Einstellungen sowie bei jedem Login oder UI-Reload neu berechnet; er ändert sich nie automatisch während du spielst.";
L["OPTIONS_DYNAMIC_OFFSET"] = "iLvl-Abstand unter deinem Durchschnitt (Standard: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Gegenstände, deren iLvl mehr als diesen Wert unter deinem durchschnittlichen angelegten Gegenstandslevel liegt, werden in diese Kategorie einsortiert.";
L["OPTIONS_USE_MAX_ILVL"] = "Den maximal möglichen iLvl jedes Gegenstands verwenden (falls verbesserbar) statt seines aktuellen iLvl";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "Wenn aktiviert, werden noch verbesserbare Gegenstände anhand des iLvl verglichen, den sie bei maximaler Verbesserung erreichen könnten, nicht anhand ihres aktuellen iLvl. Nicht verbesserbare Gegenstände sind davon nicht betroffen.";
