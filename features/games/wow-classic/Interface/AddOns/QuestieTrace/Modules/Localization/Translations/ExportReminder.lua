---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

local exportReminderLocales = {
  ["It is time to share your trace data again. Each submission only covers what happened so far, so please keep submitting regularly. %s"] = {
    ["enUS"] = true,
    ["deDE"] = "Es ist wieder Zeit, deine Trace-Daten zu teilen. Jede Übermittlung deckt nur das bisher Geschehene ab, also teile bitte regelmäßig weiter. %s", -- 🤖
    ["esES"] = "Es hora de compartir tus datos de nuevo. Cada envío solo cubre lo ocurrido hasta ahora, así que sigue compartiendo regularmente. %s", -- 🤖
    ["esMX"] = "Es hora de compartir tus datos de nuevo. Cada envío solo cubre lo ocurrido hasta ahora, así que sigue compartiendo regularmente. %s", -- 🤖
    ["frFR"] = "Il est de nouveau temps de partager vos données. Chaque envoi ne couvre que ce qui s'est passé jusqu'à présent, alors continuez à partager régulièrement. %s", -- 🤖
    ["koKR"] = "다시 추적 데이터를 공유할 시간입니다. 각 제출은 지금까지의 데이터만 포함하므로 정기적으로 계속 공유해 주세요. %s", -- 🤖
    ["ptBR"] = "É hora de compartilhar seus dados novamente. Cada envio cobre apenas o que aconteceu até agora, então continue compartilhando regularmente. %s", -- 🤖
    ["ruRU"] = "Снова пора поделиться данными трассировки. Каждая отправка охватывает только то, что произошло до сих пор, поэтому продолжайте делиться регулярно. %s", -- 🤖
    ["zhCN"] = "又到了分享追踪数据的时候了。每次提交只涵盖目前为止发生的数据，请定期继续分享。%s", -- 🤖
    ["zhTW"] = "又到了分享追蹤資料的時候了。每次提交只涵蓋目前為止發生的資料，請定期繼續分享。%s", -- 🤖
  },
  ["Click here to open the export window"] = {
    ["enUS"] = true,
    ["deDE"] = "Klicken Sie hier, um das Exportfenster zu öffnen", -- 🤖
    ["esES"] = "Haz clic aquí para abrir la ventana de exportación", -- 🤖
    ["esMX"] = "Haz clic aquí para abrir la ventana de exportación", -- 🤖
    ["frFR"] = "Cliquez ici pour ouvrir la fenêtre d'exportation", -- 🤖
    ["koKR"] = "내보내기 창을 열려면 여기를 클릭하세요", -- 🤖
    ["ptBR"] = "Clique aqui para abrir a janela de exportação", -- 🤖
    ["ruRU"] = "Нажмите здесь, чтобы открыть окно экспорта", -- 🤖
    ["zhCN"] = "点击此处打开导出窗口", -- 🤖
    ["zhTW"] = "點擊此處開啟匯出視窗", -- 🤖
  },
}

for k, v in pairs(exportReminderLocales) do
  l10n.translations[k] = v
end
