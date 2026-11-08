---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

local consentLocales = {
  ["Help improve Questie by allowing QuestieTrace to collect anonymized gameplay data, such as quest progress, positions, and loot. Your data stays on your machine unless you choose to export and share it. Do you want to help out Questie?"] = {
    ["enUS"] = true,
    ["deDE"] = "Hilf uns, Questie zu verbessern, indem du QuestieTrace erlaubst, anonymisierte Spieldaten wie Questfortschritt, Positionen und Beute zu sammeln. Deine Daten bleiben auf deinem Rechner, es sei denn, du entscheidest dich, sie zu exportieren und zu teilen. Möchtest du Questie helfen?", -- 🤖
    ["esES"] = "Ayuda a mejorar Questie permitiendo que QuestieTrace recopile datos de juego anonimizados, como progreso de misiones, posiciones y botín. Tus datos permanecen en tu computadora a menos que decidas exportarlos y compartirlos. ¿Deseas ayudar a Questie?", -- 🤖
    ["esMX"] = "Ayuda a mejorar Questie permitiendo que QuestieTrace recopile datos de juego anonimizados, como progreso de misiones, posiciones y botín. Tus datos permanecen en tu computadora a menos que decidas exportarlos y compartirlos. ¿Deseas ayudar a Questie?", -- 🤖
    ["frFR"] = "Aidez-nous à améliorer Questie en permettant à QuestieTrace de collecter des données de jeu anonymisées, telles que la progression des quêtes, les positions et le butin. Vos données restent sur votre ordinateur, sauf si vous choisissez de les exporter et de les partager. Voulez-vous aider Questie ?", -- 🤖
    ["koKR"] = "QuestieTrace가 퀘스트 진행 상황, 위치, 전리품 등의 익명화된 게임 데이터를 수집하도록 허용하여 Questie 개선을 도와주세요. 당신의 데이터는 당신의 기기에 보관되며, 당신이 내보내고 공유하기로 선택하지 않는 한 공유되지 않습니다. Questie를 도와주시겠어요?", -- 🤖
    ["ptBR"] = "Ajude a melhorar o Questie permitindo que o QuestieTrace colete dados de jogo anonimizados, como progresso de missões, posições e saques. Seus dados permanecem no seu computador, a menos que você decida exportá-los e compartilhá-los. Você gostaria de ajudar o Questie?", -- 🤖
    ["ruRU"] = "Помогите улучшить Questie, разрешив QuestieTrace собирать анонимизированные данные игровой сессии, такие как прогресс заданий, позиции и добыча. Ваши данные остаются на вашем компьютере, если вы сами не решите экспортировать и поделиться ими. Вы хотите помочь Questie?", -- 🤖
    ["zhCN"] = "通过允许 QuestieTrace 收集匿名游戏数据（如任务进度、位置和战利品）来帮助改进 Questie。您的数据保留在您的计算机上，除非您选择导出并分享。您想帮助 Questie 吗？", -- 🤖
    ["zhTW"] = "透過允許 QuestieTrace 收集匿名遊戲資料（如任務進度、位置和戰利品）來幫助改善 Questie。您的資料保留在您的電腦上，除非您選擇匯出並分享。您想幫助 Questie 嗎？", -- 🤖
  },
  ["Thank you for helping improve Questie! Your gameplay data is being collected locally on this device."] = {
    ["enUS"] = true,
    ["deDE"] = "Danke, dass du hilfst, Questie zu verbessern! Deine Spieldaten werden lokal auf diesem Gerät gesammelt.", -- 🤖
    ["esES"] = "¡Gracias por ayudar a mejorar Questie! Tus datos de juego se están recopilando localmente.", -- 🤖
    ["esMX"] = "¡Gracias por ayudar a mejorar Questie! Tus datos de juego se están recopilando localmente.", -- 🤖
    ["frFR"] = "Merci de nous aider à améliorer Questie ! Vos données de jeu sont collectées localement.", -- 🤖
    ["koKR"] = "Questie 개선에 도움을 주셔서 감사합니다! 게임 데이터가 이 기기에 로컬로 수집되고 있습니다.", -- 🤖
    ["ptBR"] = "Obrigado por ajudar a melhorar o Questie! Seus dados de jogo estão sendo coletados localmente.", -- 🤖
    ["ruRU"] = "Спасибо, что помогаете улучшить Questie! Ваши игровые данные собираются локально на этом устройстве.", -- 🤖
    ["zhCN"] = "感谢您帮助改进 Questie！您的游戏数据正在此设备上本地收集。", -- 🤖
    ["zhTW"] = "感謝您協助改善 Questie！您的遊戲資料正在此裝置上進行本機收集。", -- 🤖
  },
  ["Data collection is disabled. Use \"/qlt consent\" to change this."] = {
    ["enUS"] = true,
    ["deDE"] = "Die Datensammlung ist deaktiviert. Verwende \"/qlt consent\", um dies zu ändern.", -- 🤖
    ["esES"] = "La recopilación de datos está desactivada. Usa \"/qlt consent\" para cambiar esto.", -- 🤖
    ["esMX"] = "La recopilación de datos está desactivada. Usa \"/qlt consent\" para cambiar esto.", -- 🤖
    ["frFR"] = "La collecte de données est désactivée. Utilisez \"/qlt consent\" pour changer cela.", -- 🤖
    ["koKR"] = "데이터 수집이 비활성화되어 있습니다. \"/qlt consent\" 명령으로 변경할 수 있습니다.", -- 🤖
    ["ptBR"] = "A coleta de dados está desativada. Use \"/qlt consent\" para alterar isso.", -- 🤖
    ["ruRU"] = "Сбор данных отключён. Используйте \"/qlt consent\", чтобы изменить это.", -- 🤖
    ["zhCN"] = "数据收集已停用。使用 \"/qlt consent\" 可以更改此设置。", -- 🤖
    ["zhTW"] = "資料收集已停用。使用 \"/qlt consent\" 可以變更此設定。", -- 🤖
  },
  ["You declined data collection. If you change your mind, run \"/qlt consent\"."] = {
    ["enUS"] = true,
    ["deDE"] = "Du hast die Datensammlung abgelehnt. Wenn du deine Meinung änderst, führe \"/qlt consent\" aus.", -- 🤖
    ["esES"] = "Has rechazado la recopilación de datos. Si cambias de opinión, ejecuta \"/qlt consent\".", -- 🤖
    ["esMX"] = "Has rechazado la recopilación de datos. Si cambias de opinión, ejecuta \"/qlt consent\".", -- 🤖
    ["frFR"] = "Vous avez refusé la collecte de données. Si vous changez d'avis, exécutez \"/qlt consent\".", -- 🤖
    ["koKR"] = "데이터 수집을 거부했습니다. 생각이 바뀌면 \"/qlt consent\"를 실행하세요.", -- 🤖
    ["ptBR"] = "Você recusou a coleta de dados. Se mudar de ideia, execute \"/qlt consent\".", -- 🤖
    ["ruRU"] = "Вы отказались от сбора данных. Если передумаете, выполните \"/qlt consent\".", -- 🤖
    ["zhCN"] = "您拒绝了数据收集。如果您改变主意，请运行 \"/qlt consent\"。", -- 🤖
    ["zhTW"] = "您拒絕了資料收集。如果您改變主意，請執行 \"/qlt consent\"。", -- 🤖
  },
  ["Data collection is disabled (previously declined). Use \"/qlt consent\" to re-enable."] = {
    ["enUS"] = true,
    ["deDE"] = "Datensammlung ist deaktiviert (zuvor abgelehnt). Verwende \"/qlt consent\", um sie wieder zu aktivieren.", -- 🤖
    ["esES"] = "La recopilación de datos está desactivada (rechazada anteriormente). Usa \"/qlt consent\" para volver a activarla.", -- 🤖
    ["esMX"] = "La recopilación de datos está desactivada (rechazada anteriormente). Usa \"/qlt consent\" para volver a activarla.", -- 🤖
    ["frFR"] = "La collecte de données est désactivée (refusée précédemment). Utilisez \"/qlt consent\" pour la réactiver.", -- 🤖
    ["koKR"] = "데이터 수집이 비활성화되어 있습니다 (이전에 거부됨). \"/qlt consent\"로 다시 활성화하세요.", -- 🤖
    ["ptBR"] = "A coleta de dados está desativada (recusada anteriormente). Use \"/qlt consent\" para reativar.", -- 🤖
    ["ruRU"] = "Сбор данных отключён (ранее отклонён). Используйте \"/qlt consent\", чтобы включить снова.", -- 🤖
    ["zhCN"] = "数据收集已停用（之前已拒绝）。使用 \"/qlt consent\" 可重新启用。", -- 🤖
    ["zhTW"] = "資料收集已停用（先前已拒絕）。使用 \"/qlt consent\" 可重新啟用。", -- 🤖
  },
}



for key, locales in pairs(consentLocales) do
  l10n.translations[key] = locales
end
