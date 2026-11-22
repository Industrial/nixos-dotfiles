if GetLocale() ~= "koKR" then return end
local ns = EasyFind and EasyFind._ns
local L = ns and ns.L
if not L then return end

L["APP_DESC_CHAT"]                      = "귓속말과 채널을 위한 메신저로, 대화 기록을 남깁니다."
L["CHAT_EXP_TT"]                         = "채팅은 아직 만드는 중입니다: 일부가 제대로 동작하지 않을 수 있습니다. 어디가 잘못되는지 알려 주세요."
L["CHAT_OPT_CHATS"]                      = "대화"
L["CHAT_OPT_CHATS_TT"]                   = "대화마다 한 줄씩, 클릭하면 엽니다."
L["CHAT_OPT_MESSAGES"]                   = "메시지"
L["CHAT_OPT_MESSAGES_TT"]                = "대화의 메시지마다 한 줄씩. 기본은 끔: 너무 많습니다."
L["CHAT_COPY_NAME_TT"]                   = "또는 메시지의 이름에 마우스를 올리고 Ctrl+C를 누르세요."
L["CHAT_HOVER_COPY_NAME"]                = "이름에 마우스를 올리고 Ctrl+C."
L["EXT_NEEDS_EASYFIND_FMT"]             = "EasyFind %s 이상이 필요합니다: EasyFind를 업데이트하세요."
