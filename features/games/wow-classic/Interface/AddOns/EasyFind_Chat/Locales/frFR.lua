if GetLocale() ~= "frFR" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Une messagerie pour les chuchotements et les canaux, avec conversations et historique."
L["CHAT_EXP_TT"]                         = "Chat est encore en construction : certaines parties peuvent ne pas bien marcher. Dites-nous où ça cloche."
L["CHAT_OPT_CHATS"]                      = "Conversations"
L["CHAT_OPT_CHATS_TT"]                   = "Une ligne par conversation, pour l'ouvrir."
L["CHAT_OPT_MESSAGES"]                   = "Messages"
L["CHAT_OPT_MESSAGES_TT"]                = "Une ligne par message de vos conversations. Désactivé par défaut : il y en a beaucoup."
L["CHAT_COPY_NAME_TT"]                   = "Ou survolez le nom dans un message et appuyez sur Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]                = "Survolez le nom et Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Nécessite EasyFind %s ou plus récent : mettez EasyFind à jour."
