---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

local exportUILocales = {
  ["QuestieTrace Export"] = {
    ["enUS"] = true,
    ["deDE"] = "QuestieTrace Export", -- 🤖
    ["esES"] = "Exportar QuestieTrace", -- 🤖
    ["esMX"] = "Exportar QuestieTrace", -- 🤖
    ["frFR"] = "Export QuestieTrace", -- 🤖
    ["koKR"] = "QuestieTrace 내보내기", -- 🤖
    ["ptBR"] = "Exportar QuestieTrace", -- 🤖
    ["ruRU"] = "Экспорт QuestieTrace", -- 🤖
    ["zhCN"] = "QuestieTrace 导出", -- 🤖
    ["zhTW"] = "QuestieTrace 匯出", -- 🤖
  },
  ["Copy the text below and submit it at the URL above. Please do this again each time this window has new data to share, since one submission only covers what happened up to that point. This helps us build the Questie database. Player and guild names are never included."] = {
    ["enUS"] = true,
    ["deDE"] = "Kopieren Sie den Text unten und senden Sie ihn über die obige URL. Bitte wiederholen Sie dies jedes Mal, wenn dieses Fenster neue Daten enthält, da eine Übermittlung nur abdeckt, was bis zu diesem Zeitpunkt passiert ist. Das hilft uns, die Questie-Datenbank aufzubauen. Spielernamen und Gildennamen sind niemals enthalten.", -- 🤖
    ["esES"] = "Copia el texto de abajo y envíalo a la URL de arriba. Repite esto cada vez que esta ventana tenga nuevos datos que compartir, ya que un envío solo cubre lo ocurrido hasta ese momento. Esto nos ayuda a construir la base de datos de Questie. Los nombres de jugadores y hermandades nunca se incluyen.", -- 🤖
    ["esMX"] = "Copia el texto de abajo y envíalo a la URL de arriba. Repite esto cada vez que esta ventana tenga nuevos datos que compartir, ya que un envío solo cubre lo ocurrido hasta ese momento. Esto nos ayuda a construir la base de datos de Questie. Los nombres de jugadores y hermandades nunca se incluyen.", -- 🤖
    ["frFR"] = "Copiez le texte ci-dessous et soumettez-le à l'URL ci-dessus. Recommencez chaque fois que cette fenêtre contient de nouvelles données à partager, car une soumission ne couvre que ce qui s'est passé jusqu'à ce moment-là. Cela nous aide à construire la base de données Questie. Les noms des joueurs et des guildes ne sont jamais inclus.", -- 🤖
    ["koKR"] = "아래 텍스트를 복사하여 위의 URL에 제출해 주세요. 이 창에 새로운 데이터가 있을 때마다 다시 제출해 주세요. 한 번의 제출은 그 시점까지의 데이터만 포함합니다. 이 데이터는 퀘스티 데이터베이스 구축에 도움이 됩니다. 플레이어 및 길드 이름은 절대 포함되지 않습니다.", -- 🤖
    ["ptBR"] = "Copie o texto abaixo e envie na URL acima. Repita isso sempre que esta janela tiver novos dados para compartilhar, pois cada envio cobre apenas o que aconteceu até aquele momento. Isso nos ajuda a construir o banco de dados do Questie. Nomes de jogadores e guildas nunca são incluídos.", -- 🤖
    ["ruRU"] = "Скопируйте текст ниже и отправьте его по ссылке выше. Повторяйте это каждый раз, когда в этом окне появляются новые данные, так как одна отправка охватывает только то, что произошло до этого момента. Это помогает нам строить базу данных Questie. Имена игроков и гильдий никогда не включаются.", -- 🤖
    ["zhCN"] = "复制下方文本并提交至上方 URL。每次此窗口出现新数据时都请重复此操作，因为一次提交只涵盖到那时为止发生的数据。这些数据帮助我们构建 Questie 数据库。绝不包含玩家和公会名称。", -- 🤖
    ["zhTW"] = "複製下方文字並提交至上方 URL。每次此視窗出現新資料時都請重複此操作，因為一次提交只涵蓋到那時為止發生的資料。這些資料協助我們建構 Questie 資料庫。絕不包含玩家和公會名稱。", -- 🤖
  },
  ["Close"] = {
    ["enUS"] = true,
    ["deDE"] = "Schließen", -- 🤖
    ["esES"] = "Cerrar", -- 🤖
    ["esMX"] = "Cerrar", -- 🤖
    ["frFR"] = "Fermer", -- 🤖
    ["koKR"] = "닫기", -- 🤖
    ["ptBR"] = "Fechar", -- 🤖
    ["ruRU"] = "Закрыть", -- 🤖
    ["zhCN"] = "关闭", -- 🤖
    ["zhTW"] = "關閉", -- 🤖
  },
  ["Closes this window without marking the data as reported. You can reopen it later to submit the same data."] = {
    ["enUS"] = true,
    ["deDE"] = "Schließt dieses Fenster, ohne die Daten als gemeldet zu markieren. Sie können es später erneut öffnen, um dieselben Daten zu übermitteln.", -- 🤖
    ["esES"] = "Cierra esta ventana sin marcar los datos como reportados. Puedes volver a abrirla más tarde para enviar los mismos datos.", -- 🤖
    ["esMX"] = "Cierra esta ventana sin marcar los datos como reportados. Puedes volver a abrirla más tarde para enviar los mismos datos.", -- 🤖
    ["frFR"] = "Ferme cette fenêtre sans marquer les données comme signalées. Vous pouvez la rouvrir plus tard pour soumettre les mêmes données.", -- 🤖
    ["koKR"] = "데이터를 제출된 것으로 표시하지 않고 이 창을 닫습니다. 나중에 다시 열어 동일한 데이터를 제출할 수 있습니다.", -- 🤖
    ["ptBR"] = "Fecha esta janela sem marcar os dados como reportados. Você pode reabri-la depois para enviar os mesmos dados.", -- 🤖
    ["ruRU"] = "Закрывает это окно без пометки данных как отправленных. Вы можете открыть его позже, чтобы отправить те же данные.", -- 🤖
    ["zhCN"] = "关闭此窗口，但不会将数据标记为已报告。您可以稍后重新打开以提交相同的数据。", -- 🤖
    ["zhTW"] = "關閉此視窗，但不會將資料標記為已回報。您可以稍後重新開啟以提交相同的資料。", -- 🤖
  },
  ["I reported this"] = {
    ["enUS"] = true,
    ["deDE"] = "Ich hab's gemeldet", -- 🤖
    ["esES"] = "He reportado esto", -- 🤖
    ["esMX"] = "He reportado esto", -- 🤖
    ["frFR"] = "J'ai signalé ceci", -- 🤖
    ["koKR"] = "제출했습니다", -- 🤖
    ["ptBR"] = "Eu reportei isso", -- 🤖
    ["ruRU"] = "Я отправил это", -- 🤖
    ["zhCN"] = "我已提交", -- 🤖
    ["zhTW"] = "我已提交", -- 🤖
  },
  ["Only click this after you have copied the text above and submitted it at the URL. This marks the data as reported so it will not be shown again."] = {
    ["enUS"] = true,
    ["deDE"] = "Klicken Sie erst darauf, nachdem Sie den obigen Text kopiert und über die URL übermittelt haben. Dies markiert die Daten als gemeldet, sodass sie nicht erneut angezeigt werden.", -- 🤖
    ["esES"] = "Haz clic aquí solo después de haber copiado el texto de arriba y haberlo enviado a la URL. Esto marca los datos como reportados para que no se vuelvan a mostrar.", -- 🤖
    ["esMX"] = "Haz clic aquí solo después de haber copiado el texto de arriba y haberlo enviado a la URL. Esto marca los datos como reportados para que no se vuelvan a mostrar.", -- 🤖
    ["frFR"] = "Cliquez ici uniquement après avoir copié le texte ci-dessus et l'avoir soumis à l'URL. Cela marque les données comme signalées afin qu'elles ne soient plus affichées.", -- 🤖
    ["koKR"] = "위의 텍스트를 복사하여 URL에 제출한 후에만 클릭하세요. 이렇게 하면 데이터가 제출된 것으로 표시되어 다시 표시되지 않습니다.", -- 🤖
    ["ptBR"] = "Clique aqui somente depois de copiar o texto acima e enviá-lo para a URL. Isso marca os dados como reportados para que não sejam mostrados novamente.", -- 🤖
    ["ruRU"] = "Нажимайте только после того, как скопируете текст выше и отправите его по указанной ссылке. Это отметит данные как отправленные, чтобы они больше не показывались.", -- 🤖
    ["zhCN"] = "仅在您复制上方文本并提交至该 URL 后才点击此按钮。这会将数据标记为已报告，之后将不再显示。", -- 🤖
    ["zhTW"] = "僅在您複製上方文字並提交至該 URL 後才點擊此按鈕。這會將資料標記為已回報，之後將不再顯示。", -- 🤖
  },
  ["Nothing new to share yet. Keep playing and check back later."] = {
    ["enUS"] = true,
    ["deDE"] = "Noch nichts Neues zum Teilen. Spiele weiter und schau später noch einmal vorbei.", -- 🤖
    ["esES"] = "Todavía no hay nada nuevo que compartir. Sigue jugando y vuelve más tarde.", -- 🤖
    ["esMX"] = "Todavía no hay nada nuevo que compartir. Sigue jugando y vuelve más tarde.", -- 🤖
    ["frFR"] = "Rien de nouveau à partager pour le moment. Continuez à jouer et revenez plus tard.", -- 🤖
    ["koKR"] = "아직 공유할 새 데이터가 없습니다. 계속 플레이하고 나중에 다시 확인해 주세요.", -- 🤖
    ["ptBR"] = "Ainda não há nada novo para compartilhar. Continue jogando e volte mais tarde.", -- 🤖
    ["ruRU"] = "Пока нечем поделиться. Продолжайте играть и загляните позже.", -- 🤖
    ["zhCN"] = "目前没有新的可分享内容。继续游戏，稍后再来看看。", -- 🤖
    ["zhTW"] = "目前沒有新的可分享內容。繼續遊玩，稍後再回來看看。", -- 🤖
  },
  ["Events captured: %s"] = {
    ["enUS"] = true,
    ["deDE"] = "Erfasste Ereignisse: %s", -- 🤖
    ["esES"] = "Eventos registrados: %s", -- 🤖
    ["esMX"] = "Eventos registrados: %s", -- 🤖
    ["frFR"] = "Événements enregistrés : %s", -- 🤖
    ["koKR"] = "기록된 이벤트: %s", -- 🤖
    ["ptBR"] = "Eventos registrados: %s", -- 🤖
    ["ruRU"] = "Записано событий: %s", -- 🤖
    ["zhCN"] = "已记录事件：%s", -- 🤖
    ["zhTW"] = "已記錄事件：%s", -- 🤖
  },
  ["Time recorded: %s"] = {
    ["enUS"] = true,
    ["deDE"] = "Aufgezeichnete Zeit: %s", -- 🤖
    ["esES"] = "Tiempo registrado: %s", -- 🤖
    ["esMX"] = "Tiempo registrado: %s", -- 🤖
    ["frFR"] = "Temps enregistré : %s", -- 🤖
    ["koKR"] = "기록된 시간: %s", -- 🤖
    ["ptBR"] = "Tempo registrado: %s", -- 🤖
    ["ruRU"] = "Записано времени: %s", -- 🤖
    ["zhCN"] = "已记录时间：%s", -- 🤖
    ["zhTW"] = "已記錄時間：%s", -- 🤖
  },
  ["Quests accepted: %s"] = {
    ["enUS"] = true,
    ["deDE"] = "Angenommene Quests: %s", -- 🤖
    ["esES"] = "Misiones aceptadas: %s", -- 🤖
    ["esMX"] = "Misiones aceptadas: %s", -- 🤖
    ["frFR"] = "Quêtes acceptées : %s", -- 🤖
    ["koKR"] = "수락한 퀘스트: %s", -- 🤖
    ["ptBR"] = "Missões aceitas: %s", -- 🤖
    ["ruRU"] = "Принято заданий: %s", -- 🤖
    ["zhCN"] = "已接受任务：%s", -- 🤖
    ["zhTW"] = "已接受任務：%s", -- 🤖
  },
  ["Quests turned in: %s"] = {
    ["enUS"] = true,
    ["deDE"] = "Abgegebene Quests: %s", -- 🤖
    ["esES"] = "Misiones entregadas: %s", -- 🤖
    ["esMX"] = "Misiones entregadas: %s", -- 🤖
    ["frFR"] = "Quêtes rendues : %s", -- 🤖
    ["koKR"] = "완료 보고한 퀘스트: %s", -- 🤖
    ["ptBR"] = "Missões entregues: %s", -- 🤖
    ["ruRU"] = "Сдано заданий: %s", -- 🤖
    ["zhCN"] = "已交付任务：%s", -- 🤖
    ["zhTW"] = "已交付任務：%s", -- 🤖
  },
  ["ERROR: Client does not have required codec support (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)"] = {
    ["enUS"] = true,
    ["deDE"] = "FEHLER: Der Client verfügt nicht über die erforderliche Codec-Unterstützung (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["esES"] = "ERROR: El cliente no tiene el soporte de códec necesario (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["esMX"] = "ERROR: El cliente no tiene el soporte de códec necesario (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["frFR"] = "ERREUR : Le client ne dispose pas du support de codec requis (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["koKR"] = "오류: 클라이언트에 필요한 코덱 지원이 없습니다 (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["ptBR"] = "ERRO: O cliente não possui o suporte de codec necessário (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["ruRU"] = "ОШИБКА: клиент не поддерживает необходимые кодеки (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["zhCN"] = "错误：客户端缺少所需的编解码支持 (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
    ["zhTW"] = "錯誤：用戶端缺少所需的編解碼支援 (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)", -- 🤖
  },
  ["ERROR: Encoding failed: %s"] = {
    ["enUS"] = true,
    ["deDE"] = "FEHLER: Kodierung fehlgeschlagen: %s", -- 🤖
    ["esES"] = "ERROR: La codificación ha fallado: %s", -- 🤖
    ["esMX"] = "ERROR: La codificación falló: %s", -- 🤖
    ["frFR"] = "ERREUR : Échec de l'encodage : %s", -- 🤖
    ["koKR"] = "오류: 인코딩에 실패했습니다: %s", -- 🤖
    ["ptBR"] = "ERRO: Falha na codificação: %s", -- 🤖
    ["ruRU"] = "ОШИБКА: не удалось выполнить кодирование: %s", -- 🤖
    ["zhCN"] = "错误：编码失败：%s", -- 🤖
    ["zhTW"] = "錯誤：編碼失敗：%s", -- 🤖
  },
}

for k, v in pairs(exportUILocales) do
  l10n.translations[k] = v
end
