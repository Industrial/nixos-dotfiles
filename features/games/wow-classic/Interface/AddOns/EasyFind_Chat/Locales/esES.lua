if GetLocale() ~= "esES" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Un mensajero para susurros y canales, con conversaciones e historial."
L["CHAT_EXP_TT"]                         = "Chat aún está en construcción: puede que algunas partes no funcionen bien todavía. Cuéntanos dónde falla."
L["CHAT_OPT_CHATS"]                      = "Conversaciones"
L["CHAT_OPT_CHATS_TT"]                   = "Una fila por conversación, para abrirla."
L["CHAT_OPT_MESSAGES"]                   = "Mensajes"
L["CHAT_OPT_MESSAGES_TT"]                = "Una fila por cada mensaje de tus conversaciones. Desactivado por defecto: son muchos."
L["CHAT_COPY_NAME_TT"]                   = "O pasa el ratón por el nombre en un mensaje y pulsa Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]                = "Pasa el cursor por el nombre y pulsa Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Necesita EasyFind %s o posterior: actualiza EasyFind."
