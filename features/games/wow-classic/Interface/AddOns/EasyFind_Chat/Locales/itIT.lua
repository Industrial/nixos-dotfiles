if GetLocale() ~= "itIT" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Un messenger per sussurri e canali, con conversazioni e cronologia."
L["CHAT_EXP_TT"]                         = "Chat è ancora in costruzione: alcune parti potrebbero non funzionare bene. Dicci dove va storto."
L["CHAT_OPT_CHATS"]                      = "Conversazioni"
L["CHAT_OPT_CHATS_TT"]                   = "Una riga per ogni conversazione, per aprirla."
L["CHAT_OPT_MESSAGES"]                   = "Messaggi"
L["CHAT_OPT_MESSAGES_TT"]                = "Una riga per ogni messaggio delle tue conversazioni. Disattivato per impostazione predefinita: sono tanti."
L["CHAT_COPY_NAME_TT"]                   = "Oppure passa sul nome in un messaggio e premi Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]                = "Passa sul nome e premi Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Richiede EasyFind %s o successivo: aggiorna EasyFind."
