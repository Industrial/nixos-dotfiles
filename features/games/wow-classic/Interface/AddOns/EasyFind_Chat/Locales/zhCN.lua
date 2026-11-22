if GetLocale() ~= "zhCN" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "用于密语和频道的聊天工具，带有对话和记录。"
L["CHAT_EXP_TT"]                         = "聊天仍在开发中：有些部分可能还不正常。请告诉我们哪里出了问题。"
L["CHAT_OPT_CHATS"]                      = "对话"
L["CHAT_OPT_CHATS_TT"]                   = "每个对话一行，点击打开。"
L["CHAT_OPT_MESSAGES"]                   = "消息"
L["CHAT_OPT_MESSAGES_TT"]                = "对话中的每条消息一行。默认关闭：数量很多。"
L["CHAT_COPY_NAME_TT"]                   = "或将鼠标悬停在消息中的名字上并按 Ctrl+C。"
L["CHAT_HOVER_COPY_NAME"]                = "悬停在名字上并按Ctrl+C。"
L["EXT_NEEDS_EASYFIND_FMT"]             = "需要 EasyFind %s 或更高版本：请更新 EasyFind。"
