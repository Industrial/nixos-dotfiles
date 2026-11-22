-- Chat's own text, set into EasyFind's L: English, the source the other
-- locales override. Words EasyFind's UI shares stay in its own files.
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["CHAT_EXP_TT"]                        = "Chat is still being built: some parts may not work right yet. Please give feedback as you encounter issues."
L["CHAT_COPY_NAME_TT"]                 = "Or hover the name in a message and press Ctrl+C."
L["CHAT_HOVER_COPY_NAME"]              = "Hover name and Ctrl+C."
L["CHAT_OPT_CHATS"]                    = "Conversations"
L["CHAT_OPT_CHATS_TT"]                 = "A row for each conversation, to open it."
L["CHAT_OPT_MESSAGES"]                 = "Messages"
L["CHAT_OPT_MESSAGES_TT"]              = "A row for each message in your conversations. Off by default: there are many."
L["APP_DESC_CHAT"]                      = "A messenger for whispers and channels, with threads and history."
L["EXT_NEEDS_EASYFIND_FMT"]             = "Needs EasyFind %s or later: update EasyFind."
