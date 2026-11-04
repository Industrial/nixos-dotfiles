if(GetLocale() ~= 'itIT') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "iLvl basso";
L["OPTIONS_DESC"] = "Seleziona la soglia di iLvl per questa categoria (tutti gli oggetti con un iLvl strettamente inferiore a questo valore verranno inseriti in questa categoria). Dopo aver modificato il valore, potrebbe essere necessario ricaricare l'interfaccia.";
L["OPTIONS_INCLUDE_JUNK"] = "Includi in questa categoria gli oggetti di qualità scadente";
L["OPTIONS_REFRESH"] = "Ricarica interfaccia";
L["OPTIONS_RESET_DEFAULT"] = "Ripristina valore predefinito";
L["OPTIONS_THRESHOLD"] = "Soglia iLvl (predefinito: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Inserisci un numero valido per la soglia di iLvl.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Usa una soglia dinamica basata sul tuo iLvl medio equipaggiato";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Usa una soglia dinamica basata sul tuo iLvl medio equipaggiato (attualmente: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "Se attivato, la soglia di iLvl viene calcolata automaticamente in base al tuo livello oggetto medio equipaggiato. Viene ricalcolata ogni volta che modifichi queste impostazioni, oltre che ad ogni login o ricarica dell'interfaccia; non cambia mai automaticamente mentre giochi.";
L["OPTIONS_DYNAMIC_OFFSET"] = "Differenza di iLvl sotto la tua media (predefinito: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Gli oggetti il cui iLvl è inferiore di oltre questo valore rispetto al tuo livello oggetto medio equipaggiato verranno inseriti in questa categoria.";
L["OPTIONS_USE_MAX_ILVL"] = "Usa l'iLvl massimo possibile di ogni oggetto (se potenziabile) invece del suo iLvl attuale";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "Se attivato, gli oggetti ancora potenziabili vengono confrontati usando l'iLvl che potrebbero raggiungere al potenziamento massimo, non il loro iLvl attuale. Gli oggetti non potenziabili non sono interessati.";
