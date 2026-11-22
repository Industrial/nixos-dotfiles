if GetLocale() ~= "zhTW" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "用於密語和頻道的聊天工具，附有對話和紀錄。"
L["CHAT_EXP_TT"]                         = "聊天仍在開發中：有些部分可能還不正常。請告訴我們哪裡出了問題。"
L["CHAT_OPT_CHATS"]                      = "對話"
L["CHAT_OPT_CHATS_TT"]                   = "每個對話一行，點擊開啟。"
L["CHAT_OPT_MESSAGES"]                   = "訊息"
L["CHAT_OPT_MESSAGES_TT"]                = "對話中的每則訊息一行。預設關閉：數量很多。"
L["CHAT_COPY_NAME_TT"]                   = "或將滑鼠懸停在訊息中的名字上並按 Ctrl+C。"
L["CHAT_HOVER_COPY_NAME"]                = "懸停在名字上並按Ctrl+C。"
L["EXT_NEEDS_EASYFIND_FMT"]             = "需要 EasyFind %s 或更新版本：請更新 EasyFind。"
