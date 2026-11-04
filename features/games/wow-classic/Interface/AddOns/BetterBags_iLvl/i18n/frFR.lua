if(GetLocale() ~= 'frFR') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "iLvl faible";
L["OPTIONS_DESC"] = "Sélectionnez le seuil d'iLvl pour cette catégorie (tous les objets avec un iLvl strictement inférieur à cette valeur seront placés dans cette catégorie). Une fois la valeur changée, un rechargement de l'interface peut être nécessaire."
L["OPTIONS_INCLUDE_JUNK"] = "Inclure les objets de qualité médiocre dans cette catégorie";
L["OPTIONS_REFRESH"] = "Recharger l'interface";
L["OPTIONS_RESET_DEFAULT"] = "Remettre la valeur par défaut";
L["OPTIONS_THRESHOLD"] = "Seuil d'iLvl (par défaut : _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Veuillez entrer un nombre valide pour le seuil d'iLvl.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Utiliser un seuil dynamique basé sur votre iLvl moyen équipé";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Utiliser un seuil dynamique basé sur votre iLvl moyen équipé (actuellement : _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "Une fois activé, le seuil d'iLvl est calculé automatiquement à partir de votre iLvl moyen équipé. Il est recalculé à chaque modification de ces réglages, ainsi qu'à la connexion ou lors d'un rechargement de l'interface ; il ne change jamais automatiquement en cours de jeu.";
L["OPTIONS_DYNAMIC_OFFSET"] = "Écart d'iLvl sous votre moyenne (par défaut : _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Les objets dont l'iLvl est inférieur de plus de cette valeur à votre iLvl moyen équipé seront placés dans cette catégorie.";
L["OPTIONS_USE_MAX_ILVL"] = "Utiliser l'iLvl maximum possible de chaque objet (si améliorable) plutôt que son iLvl actuel";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "Une fois activé, les objets encore améliorables sont comparés selon l'iLvl qu'ils pourraient atteindre au maximum d'amélioration, et non leur iLvl actuel. Les objets non améliorables ne sont pas concernés.";
