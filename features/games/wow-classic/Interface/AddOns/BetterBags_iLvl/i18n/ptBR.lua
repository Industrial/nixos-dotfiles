if(GetLocale() ~= 'ptBR') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "iLvl baixo";
L["OPTIONS_DESC"] = "Selecione o limite de iLvl para esta categoria (todos os itens com iLvl estritamente abaixo deste valor serão colocados nesta categoria). Após alterar o valor, pode ser necessário recarregar a interface.";
L["OPTIONS_INCLUDE_JUNK"] = "Incluir itens de qualidade ruim nesta categoria";
L["OPTIONS_REFRESH"] = "Recarregar interface";
L["OPTIONS_RESET_DEFAULT"] = "Redefinir para o padrão";
L["OPTIONS_THRESHOLD"] = "Limite de iLvl (padrão: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Digite um número válido para o limite de iLvl.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Usar um limite dinâmico baseado no seu iLvl médio equipado";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Usar um limite dinâmico baseado no seu iLvl médio equipado (atualmente: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "Quando ativado, o limite de iLvl é calculado automaticamente com base no seu nível de item médio equipado. Ele é recalculado sempre que você altera essas configurações, e também a cada login ou recarregamento da interface; nunca muda automaticamente enquanto você está jogando.";
L["OPTIONS_DYNAMIC_OFFSET"] = "Diferença de iLvl abaixo da sua média (padrão: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Itens cujo iLvl esteja mais do que este valor abaixo do seu nível de item médio equipado serão colocados nesta categoria.";
L["OPTIONS_USE_MAX_ILVL"] = "Usar o iLvl máximo possível de cada item (se aprimorável) em vez do seu iLvl atual";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "Quando ativado, itens que ainda podem ser aprimorados são comparados usando o iLvl que poderiam alcançar no aprimoramento máximo, não o iLvl atual. Itens não aprimoráveis não são afetados.";
