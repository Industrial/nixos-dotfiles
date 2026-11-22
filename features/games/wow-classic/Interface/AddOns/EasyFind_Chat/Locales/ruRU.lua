if GetLocale() ~= "ruRU" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "Мессенджер для шепота и каналов, с беседами и историей."
L["CHAT_EXP_TT"]                         = "Чат еще в разработке: что-то может работать неправильно. Расскажите нам, где что-то не так."
L["CHAT_OPT_CHATS"]                      = "Беседы"
L["CHAT_OPT_CHATS_TT"]                   = "Строка на каждую беседу, чтобы открыть ее."
L["CHAT_OPT_MESSAGES"]                   = "Сообщения"
L["CHAT_OPT_MESSAGES_TT"]                = "Строка на каждое сообщение в ваших беседах. По умолчанию выключено: их много."
L["CHAT_COPY_NAME_TT"]                   = "Или наведите на имя в сообщении и нажмите Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]                = "Наведите на имя и нажмите Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Нужен EasyFind %s или новее: обновите EasyFind."
