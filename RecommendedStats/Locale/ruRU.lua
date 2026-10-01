-- RecommendedStats :: Locale/enUS.lua
-- Base locale table. Loaded first (see the .toc), before Data/*.lua and every UI file, so
-- everything after it can do `local L = RecommendedStats_Locale`.
-- Translator ZamestoTV
-- Extension point for a future translation: add a new Locale/<locale>.lua file, loaded AFTER
-- this one in the .toc, guarded like:
--   if GetLocale() ~= "deDE" then return end
--   local L = RecommendedStats_Locale
--   L.TAB_STATS = "..."   -- only override the keys that locale actually translates
-- No other locale ships today — this file is the only one, and every key below is the enUS text
-- used regardless of client locale until a translation file like that exists.

if GetLocale() ~= "ruRU" then return end

RecommendedStats_Locale = RecommendedStats_Locale or {}
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Shared chrome (tabs, generic fallbacks, "Got it" reused across popups)
--------------------------------------------------------------------------------
L.CHAT_PREFIX     = "|cff33ff99RecommendedStats|r"
L.ADDON_TITLE     = "Recommended Stats"
-- Short on purpose: the panel header holds four equal buttons (see enUS.lua). The longer
L.TAB_STATS       = "Статы"
L.TAB_BIS         = "BiS"
L.SELECT          = "Выбрать"
L.GOT_IT          = "Понятно"
L.SCHEMA_OUT_OF_DATE = "Данные о характеристиках устарели для этой версии аддона. Пожалуйста, обновите его."

--------------------------------------------------------------------------------
-- Core.lua — slash command / chat messages (appended to L.CHAT_PREFIX)
--------------------------------------------------------------------------------
L.MSG_CONTENT_SET      = " тип контента изменен на %s"
L.MSG_DATA_REFRESHED   = " целевые характеристики и BiS-экипировка обновлены %s (топ-%d игроков, патч %s)."
L.MSG_POSITIONS_RESET  = " позиции панелей сброшены. Перетащите панель, чтобы снова ее переместить."
L.MSG_CONTENT_STATUS   = " текущий контент: %s  (используйте: /rs raid|mythicplus|resetpos|options|skin export|skin import)"

--------------------------------------------------------------------------------
-- UI/CharacterPanel.lua
--------------------------------------------------------------------------------
L.STATUS_UNDER    = "Слишком мало"
L.STATUS_ON       = "В пределах нормы"
L.STATUS_OVER     = "Избыток \194\183 норма"
L.STATUS_SECRET   = "Здесь нельзя сравнить"
-- Colorblind-mode variants (RS:GetColorblindMode()) — shape glyph prefixed onto the same text.
-- Plain ASCII/bracket glyphs only: WoW's default client fonts (FRIZQT__.ttf etc.) don't cover the
-- Unicode geometric-shapes block, so a real triangle/circle character (▼●▲) renders as a tofu box
-- — confirmed live. The interpunct used elsewhere (\194\183, U+00B7) is Latin-1 Supplement and
-- renders fine, but that's the extent of what's safe to rely on without shipping a custom font.
L.STATUS_UNDER_CB  = "[v] Слишком мало"
L.STATUS_ON_CB     = "[=] В пределах нормы"
L.STATUS_OVER_CB   = "[^] Избыток \194\183 норма"
L.STATUS_SECRET_CB = "[?] Здесь нельзя сравнить"

L.STAT_HASTE       = "Скорость"
L.STAT_CRIT        = "Критический удар"
L.STAT_MASTERY     = "Искусность"
L.STAT_VERSATILITY = "Универсальность"
L.STAT_HASTE_SHORT       = "Скор."
L.STAT_CRIT_SHORT        = "Крит"
L.STAT_MASTERY_SHORT     = "Иск."
L.STAT_VERSATILITY_SHORT = "Унив."

L.CONTENT_RAID       = "Рейд"
L.CONTENT_MYTHICPLUS = "Эпохальный+"

L.SIZE_DEFAULT = "По умолчанию"
L.SIZE_SMALL   = "Маленький"
L.SIZE_MEDIUM  = "Средний"
L.SIZE_LARGE   = "Большой"

L.NO_TARGETS_YET = "Для вашей текущей специализации и типа контента пока нет целевых характеристик."
L.FOOTER_SAMPLE_OF_TARGET = "%d из %d игроков"
L.FOOTER_TOP_N            = "топ-%d игроков"
L.FOOTER_LINE             = "Цели: %s \194\183 %s \194\183 обновлено %s"
L.FOOTER_MAYBE_STALE      = " (данные могут быть устаревшими)"
L.CURRENT_VALUE           = "%.1f%%"
L.CURRENT_VALUE_WITH_RATING = "%d (%.1f%%)"
L.TARGET_INLINE           = "цель %.0f%%"
L.TARGET_WITH_RATING      = "цель %.0f (%.0f%%)"
-- "high" is the 90th-percentile reading among top players (RecommendedStatsNode's aggregate.js),
-- shown alongside the median target so a player can see how spread out top players actually are
-- rather than just chasing a single number — e.g. mastery can have a wide real spread even though
-- the median target looks tight. Omitted (falls back to TARGET_INLINE/TARGET_WITH_RATING above)
-- whenever a key has no "*High" field yet (data built before this existed).
L.TARGET_WITH_HIGH        = "цель %.0f%% \194\183 макс %.0f%%"
L.TARGET_WITH_RATING_AND_HIGH = "цель %.0f (%.0f%%) \194\183 макс %.0f%%"
L.DELTA_FROM_TARGET       = "%+.1f%% от цели"
L.DELTA_FROM_TARGET_WITH_RATING = "%+.0f (%+.1f%%) от цели"
L.PRIORITY_LINE           = "Приоритет: %s"
L.PRIORITY_TOOLTIP        = "Рейтинг основан на том, насколько близко сходятся показатели топовых игроков для каждой характеристики, а не на симуляции боя. Характеристика, к которой стремится большинство игроков, отображается первой; та, показатели которой сильно разнятся - последней."
L.TREND_SINCE_LOGIN       = "С последнего входа (%s): %+.1f%%"

--------------------------------------------------------------------------------
-- UI/BiSWindow.lua
--------------------------------------------------------------------------------
L.SLOT_HEAD      = "Голова"
L.SLOT_NECK      = "Шея"
L.SLOT_SHOULDER  = "Плечи"
L.SLOT_BACK      = "Спина"
L.SLOT_CHEST     = "Грудь"
L.SLOT_WRIST     = "Запястья"
L.SLOT_HANDS     = "Кисти рук"
L.SLOT_WAIST     = "Пояс"
L.SLOT_LEGS      = "Ноги"
L.SLOT_FEET      = "Ступни"
L.SLOT_FINGER_1  = "Палец 1"
L.SLOT_FINGER_2  = "Палец 2"
L.SLOT_TRINKET_1 = "Аксессуар 1"
L.SLOT_TRINKET_2 = "Аксессуар 2"
L.SLOT_MAIN_HAND = "Правая рука"
L.SLOT_OFF_HAND  = "Левая рука"

L.DIFFICULTY_HEROIC = "Героическая"
L.DIFFICULTY_NORMAL = "Обычная"

L.NEW_TAG = "НОВОЕ"
L.NO_BIS_DATA_YET = "Для вашей текущей специализации и типа контента пока нет данных о BiS-экипировке."
L.BIS_PCT_FALLBACK   = "%% из топ-%d \194\183 %s (пока нет эпохальных логов)"
L.BIS_PCT_LOW_SAMPLE = "%% из топ-%d (меньше игроков, чем обычно)"
L.BIS_PCT_PLAIN      = "%% из топ-%d"
L.BIS_TIER_LINE      = "Комплект: %d/4 \194\183 %d%% носят 4 предм."
L.BIS_SOURCE_PREFIX  = "Источник: "
L.BIS_SOURCE_WITH_DIFFICULTY = "%s (%s)"
L.BIS_ENCHANT_LABEL = "Чары: "
L.BIS_GEM_LABEL     = "Самоцвет: "
-- Rating readouts, e.g. "+56 Haste (5.0%)" — used for the item's own granted stats, and for
-- what the recommended enchant/gem itself grants. The no-percent variant is the fallback when a
-- rating-to-percent conversion rate isn't available this render (see BiSWindow.lua's
-- RatingConversion — nil when the player has zero of that rating equipped, or its value is a
-- Secret this instant per Blizzard's Secret Values system).
L.RATING_WITH_PCT = "+%d %s (%.1f%%)"
L.RATING_NO_PCT   = "+%d %s"

--------------------------------------------------------------------------------
-- UI/OptionsPanel.lua
--------------------------------------------------------------------------------
L.OPTIONS_WINDOW_POSITION  = "Положение окна"
L.ATTACH_MODE_ATTACHED = "Прикрепить к окну персонажа"
L.ATTACH_MODE_FREE     = "Не прикреплять (свободное перемещение)"
L.OPTIONS_SHOW_STATS_TAB   = "Отображать вкладку \"Рекомендуемые характеристики\""
L.OPTIONS_SHOW_BIS_TAB     = "Отображать вкладку \"BiS-экипировка\""

--------------------------------------------------------------------------------
-- UI/TalentsWindow.lua, Talents.lua
--------------------------------------------------------------------------------
L.TALENTS_BUTTON            = "Таланты"
L.TALENTS_SCOPE_OVERALL     = "В целом (все боссы / подземелья)"
L.TALENTS_SCOPE_FALLBACK    = "%s (общая сборка)"
L.TALENTS_SCOPE_DIFFICULTY  = "%s (%s)"
L.TALENTS_COPY_LONG         = "Скопировать строку сборки"
L.TALENTS_SRC_OVERALL       = "Сборка для специализации от топовых игроков"
L.TALENTS_SRC_RAID          = "Убийства этого босса (%s)"
L.TALENTS_SRC_RAID_LOWER    = "Убийства этого босса (%s) [недостаточно данных на более высокой сложности]"
L.TALENTS_SRC_DUNGEON       = "Лучшие прохождения этого подземелья"
L.TALENTS_SRC_CURRENT_RAID  = "Текущие сборки лучших игроков по логам (%s) на этом боссе (не точный билд на момент убийства)"
L.TALENTS_SRC_CURRENT_DUNGEON = "Текущие сборки лучших игроков в этом подземелье (не точный билд на момент прохождения)"
L.TALENTS_SRC_FALLBACK      = "Для этого босса/подземелья пока мало данных; показана общая сборка"
L.TALENTS_SAMPLE            = "На основе %d игроков, %d разных сборок"
L.TALENTS_NO_DATA          = "Для этой специализации пока нет данных о талантах."
L.TALENTS_NOT_READY         = "Информация о талантах пока недоступна. Повторите попытку позже."
L.TALENTS_DECODE_FAILED     = "Не удалось прочитать данные талантов. Возможно, они для другой версии игры."
L.TALENTS_TREE_TITLE        = "%s | %s"
L.TALENTS_TREE_HINT         = "Золотой = используется в этой сборке (реальный билд, максимально близкий к выбору большинства). Наведите на талант, чтобы увидеть частоту выбора."
L.TALENTS_PICKED_BY         = "Выбран у %d%% игроков (%d из %d)"
L.TALENTS_OPTION_PICKED_BY  = "%s: %d%%"
L.TALENTS_COPY_TITLE        = "Сборка талантов"
L.TALENTS_COPY_HINT         = "Скопируйте эту строку, затем используйте Импорт на странице талантов."
L.TALENTS_DIFFICULTY = { mythic = "Эпохальная", heroic = "Героическая", normal = "Обычная" }

--------------------------------------------------------------------------------
-- UI/RotationWindow.lua
--------------------------------------------------------------------------------
L.ROTATION_BUTTON          = "Ротация"
L.ROTATION_TITLE           = "%s | Ротация"
L.ROTATION_TITLE_TREE      = "%s | Ротация | %s"
L.ROTATION_SUBTITLE        = "Что нажимают лучшие игроки; собрано на основе %d убийств боссов в %s рейдах от %d игроков (все боссы объединены)."
L.ROTATION_SUBTITLE_BOSS   = "Что нажимают лучшие игроки на %s; собрано на основе %d убийств в %s рейдах от %d игроков."
L.ROTATION_BOSS_OVERALL    = "В целом (все боссы)"
L.ROTATION_HINT            = "Наведите курсор на любую иконку, чтобы узнать о заклинании и о том, как его используют лучшие игроки."
L.ROTATION_DATA_AGE        = "Данные получены на патче %s, %s."
L.ROTATION_NO_DATA         = "Для этой специализации пока нет данных о ротации."
L.ROTATION_OTHER_TREE      = "Слишком мало топовых игроков используют %s для анализа ротации, поэтому показано %s."
L.ROTATION_COL_OPENER      = "Опенер"
L.ROTATION_COL_CORE        = "Основа ротации"
L.ROTATION_COL_FILLER      = "Филлеры"
L.ROTATION_COL_CDS         = "Использование бурстов"
L.ROTATION_SECTION_PRESSES = "На чем строится ротация"
L.ROTATION_SECTION_PROCS   = "Что чем активируется"
L.ROTATION_SHARES          = "%d%% нажатий, %d%% урона"
L.ROTATION_SHARES_HEALER   = "%d%% нажатий, %d%% исцеления"
L.ROTATION_HEALER_OPENER   = "У лекарей нет фиксированного опенера. Начинайте с того, чего требует пул."
L.ROTATION_HEALER_CDS      = "Использование исцеляющих кулдаунов зависит от урона босса, а не от фиксированного времени, поэтому их нельзя считать из логов. Планируйте их под каждый бой отдельно."
L.ROTATION_KIND_COOLDOWN   = "Нажимать по кулдауну, примерно каждые %s"
L.ROTATION_KIND_SPENDER    = "Спендер (расход ресурса)"
L.ROTATION_KIND_SPENDER_AT = "Спендер, обычно нажимается при накоплении %s"
L.ROTATION_KIND_PROC       = "Только при наличии %s"
L.ROTATION_EMPOWER_RANK    = "Отпускать на уровне %s"
L.ROTATION_PROC_FROM       = "%s дается от %s." -- buff, then the press or presses that give it
L.ROTATION_AND             = " и "
L.ROTATION_PROC_RANDOM     = "%s прокает случайно."
L.ROTATION_PROC_BY         = "Расходовать с помощью %s."
L.ROTATION_PROC_STACKS     = "Сначала накопите %d эффектов."
L.ROTATION_FILLER_HINT     = "Нажимать, когда больше ничего не готово."
L.ROTATION_FILLER_NONE     = "Нет явного филлера. Поддерживайте основу ротации."
L.ROTATION_CDS_NONE        = "В этой ротации нет долгих кулдаунов."
L.ROTATION_CD_ON_PULL      = "На пуле"
L.ROTATION_CD_FIRST_AT     = "Впервые примерно на %s"
L.ROTATION_CD_TIMING       = "%s, затем примерно каждые %s"
L.ROTATION_CD_TIMING_ONCE  = "%s, один раз за бой"
L.ROTATION_CD_TOGETHER     = "Нажимать вместе с:"
L.ROTATION_CD_INSIDE       = "Приберечь для окна действия:"
L.ROTATION_ITEMS_OPENER    = "Зелье и прожимной аксессуар используются вместе с вашими бурстами."
L.ROTATION_ITEMS_CD        = "Зелье и прожимной аксессуар используются здесь."
L.ROTATION_SECONDS         = "%d сек."
L.ROTATION_MINUTES         = "%s мин."
L.ROTATION_TIP_OPENER      = "%d%% лучших игроков нажимают это в данный момент."
L.ROTATION_TIP_BUFF        = "Активен %d%% времени боя, применяется примерно %d раз за бой."
L.ROTATION_TIP_CD          = "Лучшие игроки используют это примерно %s раз за бой."
L.OPTIONS_SHOW_MINIMAP     = "Показывать значок у миникарты"
L.OPTIONS_COLORBLIND       = "Иконки для режима цветовой слепоты"
L.OPTIONS_ROW_SIZE         = "Размер строки Recommended Stats"
L.OPTIONS_SKIN             = "Оформление"
L.SKIN_DEFAULT = "По умолчанию"
L.SKIN_CLASS   = "Цвет класса"
L.SKIN_CUSTOM  = "Свой цвет"
L.OPTIONS_EXPORT_SKIN = "Экспорт"
L.OPTIONS_IMPORT_SKIN = "Импорт"
L.OPTIONS_DISCLAIMER = "Recommended Stats сам по себе не увеличит ваш ДПС \226\128\148 он лишь помогает достичь правильного соотношения характеристик для вашей специализации."

--------------------------------------------------------------------------------
-- UI/MinimapButton.lua
--------------------------------------------------------------------------------
L.MINIMAP_TOOLTIP_LEFT  = "ЛКМ: показать/скрыть панели"
L.MINIMAP_TOOLTIP_RIGHT = "ПКМ: настройки"

--------------------------------------------------------------------------------
-- UI/CopyPopup.lua (generic fallback defaults — callers usually pass their own)
--------------------------------------------------------------------------------
L.COPY_APPLY            = "Применить"
L.COPY_APPLIED          = "Применено."
L.COPY_SOMETHING_WRONG  = "Что-то пошло не так."

--------------------------------------------------------------------------------
-- UI/SkinShare.lua
--------------------------------------------------------------------------------
L.SKIN_EXPORT_TITLE = "Экспорт оформления"
L.SKIN_EXPORT_HINT  = "Скопируйте этот код, чтобы поделиться им (Ctrl+A, Ctrl+C):"
L.SKIN_IMPORT_TITLE = "Импорт оформления"
L.SKIN_IMPORT_HINT  = "Вставьте код оформления RecommendedStats:"
L.SKIN_ERR_NOT_A_CODE   = "Этот код не является кодом оформления RecommendedStats."
L.SKIN_ERR_BAD_COLOR    = "В коде оформления отсутствуют или повреждены данные о цвете."
L.SKIN_ERR_UNRECOGNIZED = "Нераспознанное оформление \"%s\"."
L.SKIN_APPLIED          = "Оформление применено."

--------------------------------------------------------------------------------
-- UI/RatingNudge.lua
--------------------------------------------------------------------------------
L.RATING_NUDGE_TITLE = "Нравится RecommendedStats?"
L.RATING_NUDGE_HINT  = "Если аддон оказался полезен, оценка на CurseForge очень поможет проекту:"
