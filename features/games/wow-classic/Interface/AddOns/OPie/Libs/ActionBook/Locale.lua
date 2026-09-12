local L, _, T = 0, ...
if T.SkipLocalActionBook then return end
L, T.ActionBook.LW = T.ActionBook.LW, nil

local C, z, V, K = GetLocale(), nil
V =
    C == "deDE" and { -- 45/49 (91%)
      "Fähigkeiten", z, "Auch Gegenstände mit gleichem Namen nutzen", "Erscheinungsbild gesperrt", "Erscheinungsbild entsperrt", "Kampfhaustier", "Kampfhaustiere", "Kalender", z, "Eigenes Makro",
      "Reitdrache", "Ausrüstungsset", "Ausrüstungsslot", "Ausrüstungssets", "Ausgerüstet", "Zusätzlicher Aktionsbutton", "Flugreittier", "Gründerspitze", "Spielmenü", "Bodenreittier",
      z, "Interface Fenster", "Gegenstand", "Gegenstände", "Makro", "Makros", "Verschiedenes", "Reittier", "Reittiere", "Neues Makro",
      "Zeige nur wenn angelegt", "Outfit", "Ausstattungen", "Begleiterfähigkeit", "Begleiterfähigkeiten", "Zielmarkierungssymbol", "Weltmarkierung", "Markierungssymbole", "Klingenschluchtküste", "Zeige einen Platzhalter wenn nicht verfügbar",
      "Zauber", "Spielzeug", "Spielzeuge", "UI Fenster", z, "Erneut benutzen, damit dieses Aussehen durch eine Situation ersetzt werden kann.", "Erneut benutzen, um zu verhindern, dass dieses Aussehen durch eine Situation ersetzt wird.", "Benutze den höchsten bekannten Rang", "Zonenfähigkeiten",
    }
    or C == "esES" and { -- 43/49 (87%)
      "Habilidades", z, "Usar otros artículos con el mismo nombre", "Apariencia bloqueada", "Apariencia desbloqueada", "Mascota de duelo", "Mascotas de duelo", "Calendario", z, "Macro personalizado",
      "Montura de Dracoequitación", "Conjunto de equipamiento", "Hueco de Equipo", "Conjuntos de equipamiento", "Equipado", "Botón de acción extra", "Montura voladora", "Punto de la Fundadora", "Menú de juego", "Montura terrestre",
      z, "Panel de interfaz", "Artículo", "Artículos", "Macro", "Macros", "Misceláneo", "Montura", "Monturas", "Nueva macro",
      "Mostrar sólo al equipar", "Atuendo", z, "Habilidad de mascota", "Habilidades de mascota", "Marcador de objetivo", "Marcador del mundo", "Marcadores del mundo", "Costas del Ventajo", "Mostrar un marcador cuando no esté disponible",
      "Hechizo", "Juguete", "Juguetes", "Paneles de IU", z, z, "Usar otra vez para prevenir que esta apariencia sea reemplazada por una Situación.", "Usar el rango mas alto", "Habilidades de zona",
    }
    or C == "esMX" and { -- 49/49 (100%)
      "Habilidades", "Acción", "Usar otros artículos con el mismo nombre", "Apariencia bloqueada", "Apariencia desbloqueada", "Mascota de duelo", "Mascotas de duelo", "Calendario", "Entre facciones", "Macro personalizado",
      "Montura de vuelo de dragón", "Conjunto de equipamientos", "Ranura de equipo", "Conjuntos de equipamiento", "Equipado", "Botón de acción extra", "Montura voladora", "Punto del Fundador", "Menú de juego", "Montura terrestre",
      "Viviendas", "Panel de interfaz", "Artículo", "Artículos", "Macro", "Macros", "Misceláneo", "Montura", "Monturas", "Nueva Macro",
      "Mostrar sólo al equipar", "Indumentaria", "Atuendos", "Hablidad de mascota", "Habilidades de mascota", "Marcador del mundo", "Marcador del mundo", "Marcadores del mundo", "Costas del Ventajo", "Mostrar un sustituto cuando no esté disponible",
      "Hechizo", "Juegete", "Juguetes", "Paneles de interfaz de usuario", "Desbloquear apariencia al cambiar", "Usa de nuevo para permitir que esta apariencia se reemplace con una Situación", "Usa de nuevo para prevenir que esta apariencia se reemplace por una Situación", "Usar el rango más alto conocido", "Habilidades de area",
    }
    or C == "frFR" and { -- 45/49 (91%)
      "Compétences", z, "Également utiliser l'élément avec le même nom", "Apparence verrouillée", "Apparence déverrouillée", "Mascotte de combat", "Mascottes de combat", "Calendrier", z, "Macro personnalisée",
      "Monture draconique", "Set d'équipement", "Emplacement d'équipement", "Équipement de sets", "Équipés", "Bouton d'action supplémentaire", "Montures volantes", "Cap Fondateur", "Menu de jeu", "Monture terrestre",
      z, "Fenêtre", "Objet", "Objets", "Macro", "Macros", "Divers", "Monture", "Montures", "Nouvelle Macro",
      "Afficher seulement quand équipé", "Tenue", "Tenues", "Compétence du Familier", "Compétences du familier", "Marqueur de Raid", "Marqueur de Terrain", "Marqueurs de Raid", "Rivages de Tranchevent", "Afficher un remplacement quand indisponible",
      "Sort", "Jouet", "Jouets", "Fenêtres de l'interface", z, "Réactivez pour permettre le remplacement de cette tenue par une situation.", "Réactivez pour empêcher le remplacement de cette apparence par une situation.", "Utiliser le rang le plus élevé connu", "Compétences de zone",
    }
    or C == "itIT" and { -- 42/49 (85%)
      "Abilità", z, "Usa anche gli oggetti con lo stesso nome", "Aspetto non modificabile", "Aspetto modificabile", "Mascotte", "Mascotte", "Calendario", z, "Macro Personalizzate",
      "Cavalcatura da Dragonriding", "Set equipaggiamento", "Slot equipaggiamento", "Collezione di set", "Equipaggiato", "Pulsante azioni extra", "Cavalcatura volante", "Punta della Fondazione", "Menu di gioco", "Cavalcatura terrestre",
      z, "Pannello UI", "Oggetto", "Oggetti", "Macro", "Le macro", "Varie", "Cavalcatura", "Cavalcature", "Nuova Macro",
      "Mostra solo se equipaggiato", "Completo", z, "Abilità del famiglio", "Collezione abilità del famiglio", "Segnalini Raid", "Segnalini raid mondiali", "Segnalini raid", "Sponde Brezza Aguzza", "Mostra un segnaposto quando non disponibile",
      "Incantesimo", "Giocattolo", "Giocattoli", "Pannelli UI", z, z, z, "Usare il grado più alto conosciuto.", "Abilità di Zona.",
    }
    or C == "koKR" and { -- 45/49 (91%)
      "능력", z, "같은 이름의 아이템 사용", "외형 잠금", "외형 잠금 해제", "애완동물 대전", "전투 애완동물", "달력", z, "사용자 정의 매크로",
      "용조련술 탈것", "장비 구성", "장비 칸", "장비 구성", "착용", "추가 행동 버튼", "비행 탈것", "개척자의 터전", "게임 메뉴", "지상 탈것",
      z, "인터페이스 메뉴", "아이템", "아이템", "매크로", "매크로", "기타", "탈것", "탈것", "새 매크로",
      "착용 시에만 표시", "의상", "의상", "소환수 능력", "소환수 능력", "공격대 징표", "공격대 바닥 징표", "공격대 징표", "칼끝바람 해안", "사용 불가능할 때 점선으로 표시",
      "주문", "장난감", "장난감", "UI 메뉴", z, "이 모양을 상황으로 대체하려면 다시 사용하세요.", "이 표시가 상황으로 대체되는 것을 방지하려면 다시 사용하세요.", "가장 높은 등급 기술 사용", "지역 기술",
    }
    or C == "ruRU" and { -- 43/49 (87%)
      "Способности", z, "Использовать предметы с таким же именем", z, z, "Боевой питомец", "Боевые питомцы", "Календарь", z, "Пользовательские макросы",
      "Средство передвижения для полётов на драконе", "Комплект экипировки", "Ячейка экипировки", "Комплекты экипировки", "Надето", "Дополнительная кнопка действия", "Воздушные средства передвижения", "Лагерь Основателя", "Главное меню", "Наземные средства передвижения",
      z, "Панель интерфейса", "Предмет", "Предметы", "Макрос", "Макросы", "Разное", "Средство передвижения", "Средства передвижения", "Новый Макрос",
      "Показывать только если надет", "Снаряжение", "Модели", "Способности питомца", "Способности питомцев", "Рейдовая метка", "Метка рейда", "Рейдовые метки", "Берега Колючего Ветра", "Всегда показывать этот фрагмент",
      "Заклинание", "Игрушки", "Игрушки", "Панели пользовательского интерфейса", z, "Используйте ещё раз, чтобы разрешить изменять этот облик по ситуации.", "Используйте ещё раз, чтобы запретить изменять этот облик по ситуации.", "Использовать наивысший изученный ранг", "Способности местности",
    }
    or C == "zhCN" and { -- 49/49 (100%)
      "技能", "动作条动作", "同时使用同名物品", "外观已锁定", "外观已解锁", "战斗宠物", "战斗宠物", "日历", "跨阵营", "自定义宏",
      "驭龙术坐骑", "装备方案", "装备栏位", "装备套装", "可使用装备", "额外技能", "飞行坐骑", "创始者之角", "主菜单", "地面坐骑",
      "家宅", "界面面板", "物品", "物品", "宏", "宏", "杂项", "坐骑", "坐骑", "新建宏",
      "仅在装备时显示", "外观方案", "幻化套装", "宠物技能", "宠物技能", "团队标记", "世界标记", "团队标记", "烈风海岸", "不可用时仍显示（变暗）",
      "法术", "玩具", "玩具", "UI面板", "切换后解锁该外观", "再次点击以允许该外观被情景外观替换。", "再次点击以禁止该外观被情景外观替换。", "使用已学会的最高等级技能", "区域能力",
    }
    or C == "zhTW" and { -- 45/49 (91%)
      "技能", z, "也要使用名稱相同的物品", "外觀已鎖定", "外觀已解鎖", "戰寵", "戰寵", "行事曆", z, "自訂巨集",
      "飛龍騎術坐騎", "套裝", "裝備欄位", "套裝", "已裝備", "額外動作按鈕", "飛行坐騎", "開拓角", "遊戲選項", "地面坐騎",
      z, "介面視窗", "物品", "物品", "巨集", "巨集", "雜項", "坐騎", "坐騎", "新增巨集",
      "只有裝備在身上時才顯示", "服裝", "套裝", "寵物技能", "寵物技能", "團隊標記圖示", "團隊世界標記圖示", "團隊標記圖示", "烈風海岸", "無法使用時顯示暫代圖示",
      "技能", "玩具", "玩具", "介面視窗", z, "再次使用來允許此外觀由情境替換。", "再次使用來避免此外觀由情境替換。", "使用已學會的最高等級", "區域能力",
    }
    or C == "ptBR" and { -- 45/49 (91%)
      "Habilidades", z, "Também usar itens com o mesmo nome", "Aparência bloqueada", "Aparência desbloqueado", "Batalha de mascote", "Mascotes de batalha", "Calendário", z, "Macro Personalizada",
      "Montaria de Dragonaria", "Conjunto de equipamento", "Slot de Equipamento", "Conjuntos de equipamentos", "Equipado", "Botão de ação extra", "Montaria Voadora", "Marco do Fundador", "Menu do Jogo", "Montaria Terrestre",
      z, "Painel de Interface", "Item", "Itens", "Macro", "Macros", "Variados", "Montaria", "Montarias", "Novo Macro",
      "Apenas mostrar quando equipado", "Roupa", "Conjuntos", "Habilidade de Mascote", "Habilidades de Mascote", "Marcadores de Raide", "Marcadores Globais de Raide", "Marcadores de raide", "Costa dos Ventos Cortantes", "Sempre mostrar essa fatia quando indisponível",
      "Feitiço", "Brinquedo", "Brinquedos", "Painéis de UI", z, "Use novamente para permitir substituir esta aparência por uma Situação.", "Use novamente para prevenir que esta aparência seja substituído por uma Situação.", "Usar o mais alto ranque conhecido", "Habilidades da Zona",
    } or nil

K = V and {
      "Abilities", "Action", "Also use items with the same name", "Appearance locked", "Appearance unlocked", "Battle Pet", "Battle pets", "Calendar", "Cross-Faction", "Custom Macro",
      "Dragonriding Mount", "Equipment Set", "Equipment Slot", "Equipment sets", "Equipped", "Extra Action Button", "Flying Mount", "Founder's Point", "Game Menu", "Ground Mount",
      "Housing", "Interface Panel", "Item", "Items", "Macro", "Macros", "Miscellaneous", "Mount", "Mounts", "New Macro",
      "Only show when equipped", "Outfit", "Outfits", "Pet Ability", "Pet abilities", "Raid Marker", "Raid World Marker", "Raid markers", "Razorwind Shores", "Show a placeholder when unavailable",
      "Spell", "Toy", "Toys", "UI panels", "Unlock appearance when switching", "Use again to allow this apperance to be replaced by a Situation.", "Use again to prevent this apperance from being replaced by a Situation.", "Use the highest known rank", "Zone Abilities",
}

for i=1,K and #K or 0 do
	L[K[i]] = V[i]
end