if GetLocale() ~= "deDE" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Ein Messenger für Flüstern und Kanäle, mit Verläufen und Unterhaltungen."
L["CHAT_EXP_TT"]                         = "Chat ist noch im Bau: Manches funktioniert vielleicht noch nicht richtig. Sagt uns, wo es hakt."
L["CHAT_OPT_CHATS"]                      = "Unterhaltungen"
L["CHAT_OPT_CHATS_TT"]                   = "Eine Zeile je Unterhaltung, um sie zu öffnen."
L["CHAT_OPT_MESSAGES"]                   = "Nachrichten"
L["CHAT_OPT_MESSAGES_TT"]                = "Eine Zeile je Nachricht in euren Unterhaltungen. Standardmäßig aus: Es sind viele."
L["CHAT_COPY_NAME_TT"]                   = "Oder fahrt in einer Nachricht über den Namen und drückt Strg+C."
L["CHAT_HOVER_COPY_NAME"]                = "Namen überfahren und Strg+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Benötigt EasyFind %s oder neuer: Bitte EasyFind aktualisieren."
