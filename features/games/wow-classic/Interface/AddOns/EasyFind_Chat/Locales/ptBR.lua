if GetLocale() ~= "ptBR" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Um mensageiro para sussurros e canais, com conversas e histórico."
L["CHAT_EXP_TT"]                         = "Chat ainda está em construção: algumas partes podem não funcionar direito. Conte para nós onde dá errado."
L["CHAT_OPT_CHATS"]                      = "Conversas"
L["CHAT_OPT_CHATS_TT"]                   = "Uma linha para cada conversa, para abri-la."
L["CHAT_OPT_MESSAGES"]                   = "Mensagens"
L["CHAT_OPT_MESSAGES_TT"]                = "Uma linha para cada mensagem das suas conversas. Desligado por padrão: são muitas."
L["CHAT_COPY_NAME_TT"]                   = "Ou passe o mouse sobre o nome em uma mensagem e pressione Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]                = "Passe o mouse no nome e Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Requer o EasyFind %s ou mais recente: atualize o EasyFind."
