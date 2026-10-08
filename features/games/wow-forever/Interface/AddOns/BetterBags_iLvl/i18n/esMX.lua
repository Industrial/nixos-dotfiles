if(GetLocale() ~= 'esMX') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "Nivel de objeto bajo";
L["OPTIONS_DESC"] = "Selecciona el umbral de nivel de objeto para esta categoría (todos los objetos con un nivel de objeto estrictamente por debajo de este valor se colocarán en esta categoría). Al cambiar el valor, podría ser necesario recargar la interfaz.";
L["OPTIONS_INCLUDE_JUNK"] = "Incluir objetos de calidad pobre en esta categoría";
L["OPTIONS_REFRESH"] = "Recargar interfaz";
L["OPTIONS_RESET_DEFAULT"] = "Restablecer valor predeterminado";
L["OPTIONS_THRESHOLD"] = "Umbral de nivel de objeto (predeterminado: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Ingresa un número válido para el umbral de nivel de objeto.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Usar un umbral dinámico basado en tu nivel de objeto promedio equipado";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Usar un umbral dinámico basado en tu nivel de objeto promedio equipado (actualmente: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "Al activarse, el umbral de nivel de objeto se calcula automáticamente según tu nivel de objeto promedio equipado. Se vuelve a calcular cada vez que cambias esta configuración, y también al iniciar sesión o recargar la interfaz; nunca cambia automáticamente mientras juegas.";
L["OPTIONS_DYNAMIC_OFFSET"] = "Diferencia de nivel de objeto por debajo de tu promedio (predeterminado: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Los objetos cuyo nivel de objeto sea inferior a tu nivel de objeto promedio equipado por más de este valor se colocarán en esta categoría.";
L["OPTIONS_USE_MAX_ILVL"] = "Usar el nivel de objeto máximo posible de cada objeto (si se puede mejorar) en lugar de su nivel de objeto actual";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "Al activarse, los objetos que todavía se pueden mejorar se comparan usando el nivel de objeto que podrían alcanzar con la mejora máxima, no su nivel de objeto actual. Los objetos que no se pueden mejorar no se ven afectados.";
