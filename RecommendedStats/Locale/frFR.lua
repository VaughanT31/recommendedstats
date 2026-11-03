-- RecommendedStats :: Locale/frFR.lua
-- French localization file.

if GetLocale() ~= "frFR" then return end
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Shared chrome (tabs, generic fallbacks, "Got it" reused across popups)
--------------------------------------------------------------------------------
L.CHAT_PREFIX      = "|cff33ff99RecommendedStats|r"
L.ADDON_TITLE      = "Recommended Stats"
-- Short on purpose: the panel header holds four equal buttons (Stats, BiS, Talents, Priorities).
L.TAB_STATS        = "Stats"
L.TAB_BIS          = "BiS"
L.SELECT           = "Sélectionner"
L.GOT_IT           = "J'ai compris"
L.SCHEMA_OUT_OF_DATE = "Les données de statistiques sont obsolètes pour cette version de l'addon. Veuillez le mettre à jour."

--------------------------------------------------------------------------------
-- Core.lua — slash command / chat messages (appended to L.CHAT_PREFIX)
--------------------------------------------------------------------------------
L.MSG_CONTENT_SET      = " contenu défini sur %s"
L.MSG_DATA_REFRESHED   = " les cibles de statistiques et l'équipement BiS ont été mis à jour le %s (top %d joueurs, patch %s)."
L.MSG_POSITIONS_RESET  = " positions des panneaux réinitialisées. Glissez un panneau pour le déplacer à nouveau."
L.MSG_CONTENT_STATUS   = " contenu = %s  (utilisez /rs raid|mythicplus|bis|talents|rotation|link|resetpos|options|skin export|skin import)"

--------------------------------------------------------------------------------
-- UI/CharacterPanel.lua
--------------------------------------------------------------------------------
L.STATUS_UNDER    = "Trop bas"
L.STATUS_ON       = "Cible atteinte"
L.STATUS_OVER     = "Trop haut \194\183 correct"
L.STATUS_SECRET   = "Impossible de comparer ici"
-- Colorblind-mode variants (RS:GetColorblindMode()) — shape glyph prefixed onto the same text.
-- Plain ASCII/bracket glyphs only: WoW's default client fonts (FRIZQT__.ttf etc.) don't cover the
-- Unicode geometric-shapes block, so a real triangle/circle character (▼●▲) renders as a tofu box
-- — confirmed live. The interpunct used elsewhere (\194\183, U+00B7) is Latin-1 Supplement and
-- renders fine, but that's the extent of what's safe to rely on without shipping a custom font.
L.STATUS_UNDER_CB  = "[v] Trop bas"
L.STATUS_ON_CB     = "[=] Cible atteinte"
L.STATUS_OVER_CB   = "[^] Trop haut \194\183 correct"
L.STATUS_SECRET_CB = "[?] Impossible de comparer ici"

L.STAT_HASTE       = "Hâte"
L.STAT_CRIT        = "Coup critique"
L.STAT_MASTERY     = "Maîtrise"
L.STAT_VERSATILITY = "Polyvalence"
L.STAT_HASTE_SHORT       = "Hâte"
L.STAT_CRIT_SHORT        = "Crit"
L.STAT_MASTERY_SHORT     = "Maîtrise"
L.STAT_VERSATILITY_SHORT = "Poly"
-- Classic versions: Hit and Expertise rows show a cap rather than a top-player target.
L.STAT_HIT             = "Toucher"
L.STAT_SPELLHIT        = "Toucher des sorts"
L.STAT_EXPERTISE       = "Expertise"
L.STAT_HIT_SHORT       = "Toucher"
L.STAT_SPELLHIT_SHORT  = "Toucher"
L.STAT_EXPERTISE_SHORT = "Exp"
L.CAP_TARGET           = "cap %d (%.1f%%)"
-- Classic Era / SoD: Hit and Crit as the % your gear's "Equip:" effects give
L.STAT_HIT_GEAR        = "Toucher (équipement)"
L.STAT_CRIT_GEAR       = "Crit (équipement)"

L.CONTENT_RAID       = "Raid"
L.CONTENT_MYTHICPLUS = "Mythique+"

L.SIZE_DEFAULT = "Par défaut"
L.SIZE_SMALL   = "Petit"
L.SIZE_MEDIUM  = "Moyen"
L.SIZE_LARGE   = "Grand"

L.NO_TARGETS_YET = "Aucune cible de statistiques pour votre spécialisation et votre contenu actuels."
L.FOOTER_SAMPLE_OF_TARGET = "%d sur %d joueurs"
L.FOOTER_TOP_N            = "top %d joueurs"
L.FOOTER_LINE             = "Cibles : %s \194\183 %s \194\183 mis à jour le %s"
L.FOOTER_MAYBE_STALE      = " (peut être obsolète)"
L.CURRENT_VALUE           = "%.1f%%"
L.CURRENT_VALUE_WITH_RATING = "%d (%.1f%%)"
L.TARGET_INLINE           = "cible %.0f%%"
L.TARGET_WITH_RATING      = "cible %.0f (%.0f%%)"
-- "high" is the 90th-percentile reading among top players (RecommendedStatsNode's aggregate.js),
-- shown alongside the median target so a player can see how spread out top players actually are
-- rather than just chasing a single number — e.g. mastery can have a wide real spread even though
-- the median target looks tight. Omitted (falls back to TARGET_INLINE/TARGET_WITH_RATING above)
-- whenever a key has no "*High" field yet (data built before this existed).
L.TARGET_WITH_HIGH        = "cible %.0f%% \194\183 top %.0f%%"
L.TARGET_WITH_RATING_AND_HIGH = "cible %.0f (%.0f%%) \194\183 top %.0f%%"
L.DELTA_FROM_TARGET       = "%+.1f%% par rapport à la cible"
L.DELTA_FROM_TARGET_WITH_RATING = "%+.0f (%+.1f%%) par rapport à la cible"
L.PRIORITY_LINE           = "Priorité : %s"
L.PRIORITY_TOOLTIP        = "Classé selon la concentration des valeurs des meilleurs joueurs pour chaque statistique, et non par valeur de combat simulée. Une statistique sur laquelle la plupart des joueurs convergent apparaît en premier ; celle avec une grande dispersion apparaît en dernier."
L.TREND_SINCE_LOGIN       = "Depuis la dernière connexion (%s) : %+.1f%%"

--------------------------------------------------------------------------------
-- UI/BiSWindow.lua
--------------------------------------------------------------------------------
L.SLOT_HEAD      = "Tête"
L.SLOT_NECK      = "Cou"
L.SLOT_SHOULDER  = "Épaules"
L.SLOT_BACK      = "Dos"
L.SLOT_CHEST     = "Torse"
L.SLOT_WRIST     = "Poignets"
L.SLOT_HANDS     = "Mains"
L.SLOT_WAIST     = "Taille"
L.SLOT_LEGS      = "Jambes"
L.SLOT_FEET      = "Pieds"
L.SLOT_FINGER_1  = "Doigt 1"
L.SLOT_FINGER_2  = "Doigt 2"
L.SLOT_TRINKET_1 = "Bijou 1"
L.SLOT_TRINKET_2 = "Bijou 2"
L.SLOT_MAIN_HAND = "Main principale"
L.SLOT_OFF_HAND  = "Main gauche"
L.SLOT_RANGED    = "À distance"

L.DIFFICULTY_HEROIC = "Héroïque"
L.DIFFICULTY_NORMAL = "Normal"

L.NEW_TAG = "NOUVEAU"
L.NO_BIS_DATA_YET = "Aucune donnée BiS pour votre spécialisation et votre contenu actuels."
L.BIS_PCT_FALLBACK   = "%% du top %d \194\183 %s (pas encore de logs Mythiques)"
L.BIS_PCT_LOW_SAMPLE = "%% du top %d (échantillon plus faible que d'habitude)"
L.BIS_PCT_PLAIN      = "%% du top %d"
L.BIS_TIER_LINE      = "Tier : %d/4 \194\183 %d%% jouent avec 4 pièces"
L.BIS_WINDOW_TITLE   = "Équipement BiS | %s"
L.BIS_WINDOW_HINT    = "Maj+clic : lier dans le chat \194\183 Ctrl+clic : aperçu"
L.BIS_SOURCE_PREFIX  = "Source : "
L.BIS_SOURCE_WITH_DIFFICULTY = "%s (%s)"
L.BIS_ENCHANT_LABEL = "Enchantement "
L.BIS_GEM_LABEL     = "Sertissage "
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
L.OPTIONS_WINDOW_POSITION  = "Position de la fenêtre"
L.ATTACH_MODE_ATTACHED = "Attacher à l'écran de personnage"
L.ATTACH_MODE_FREE     = "Détaché (déplacement libre)"
L.OPTIONS_SHOW_STATS_TAB   = "Afficher l'onglet \"Stats\""
L.OPTIONS_SHOW_BIS_TAB     = "Afficher le bouton \"BiS\""

--------------------------------------------------------------------------------
-- UI/TalentsWindow.lua, Talents.lua
--------------------------------------------------------------------------------
L.TALENTS_BUTTON            = "Talents"
-- MoP Classic talents window (UI/TalentsWindowMists.lua)
L.MISTS_TALENTS_TITLE      = "Talents : %s"
L.MISTS_TALENTS_TIER       = "Niveau %d"
L.MISTS_TALENTS_GLYPHS     = "Glyphes"
L.MISTS_TALENTS_YOURS      = "votre choix"
L.MISTS_TALENTS_PICK       = "%d%% des meilleurs joueurs"
L.MISTS_TALENTS_ALT        = "ou %s (%d%%)"
L.MISTS_TALENTS_SAMPLE     = "Basé sur les meilleurs combats de %d joueurs (Warcraft Logs)."
L.MISTS_TALENTS_NONE       = "Aucune donnée de talents pour cette spécialisation."
-- TBC talents window (UI/TalentsWindowTBC.lua) and spec name
L.TBC_TALENTS_BUILD        = "%d%% des meilleurs joueurs"
L.TBC_BEAR                 = "Ours"
L.TALENTS_SCOPE_OVERALL     = "Général (tous les boss / donjons)"
L.TALENTS_SCOPE_FALLBACK    = "%s (build général)"
L.TALENTS_SCOPE_DIFFICULTY  = "%s (%s)"
L.TALENTS_COPY_LONG         = "Copier la configuration"
L.TALENTS_SRC_OVERALL       = "Build global de la spécialisation (top joueurs)"
L.TALENTS_SRC_RAID          = "Victoires contre ce boss (%s)"
L.TALENTS_SRC_RAID_LOWER    = "Victoires contre ce boss (%s - pas assez de victoires en difficulté supérieure)"
L.TALENTS_SRC_DUNGEON       = "Meilleures clés dans ce donjon"
L.TALENTS_SRC_CURRENT_RAID  = "Builds actuels des meilleurs parseurs (%s) sur ce boss (pas le build exact du kill)"
L.TALENTS_SRC_CURRENT_DUNGEON = "Builds actuels des meilleurs joueurs dans ce donjon (pas le build exact de la run)"
L.TALENTS_SRC_FALLBACK      = "Pas encore assez de données, affichage du build global de la spécialisation"
L.TALENTS_SAMPLE            = "Basé sur %d joueurs, %d builds différents"
L.TALENTS_NO_DATA           = "Aucune donnée de talents pour cette spécialisation."
L.TALENTS_NOT_READY         = "Les informations sur les talents ne sont pas encore disponibles. Réessayez dans un instant."
L.TALENTS_DECODE_FAILED     = "Impossible de lire ces données de talents. Elles proviennent peut-être d'une autre version du jeu."
L.TALENTS_TREE_TITLE        = "%s | %s"
L.TALENTS_TREE_HINT         = "Or = dans ce build (le build réel le plus proche de ce que choisit la majorité). Survolez un talent pour voir son taux de sélection."
L.TALENTS_PICKED_BY         = "Choisi par %d%% des joueurs (%d sur %d)"
L.TALENTS_OPTION_PICKED_BY  = "%s : %d%%"
L.TALENTS_COPY_TITLE        = "Configuration de talents"
L.TALENTS_COPY_HINT         = "Copiez cette chaîne, puis utilisez Importer sur la page des talents."
L.TALENTS_DIFFICULTY = { mythic = "Mythique", heroic = "Héroïque", normal = "Normal" }

--------------------------------------------------------------------------------
-- UI/RotationWindow.lua
--------------------------------------------------------------------------------
L.ROTATION_BUTTON          = "Priorités"
L.ROTATION_TITLE           = "%s | Priorités"
L.ROTATION_TITLE_TREE      = "%s | Priorités | %s"
L.ROTATION_SUBTITLE        = "Ce que les meilleurs joueurs utilisent, analysé à partir de %d combats de raid (%s) par %d joueurs (tous boss confondus)."
L.ROTATION_SUBTITLE_BOSS   = "Ce que les meilleurs joueurs utilisent sur %s, analysé à partir de %d combats (%s) par %d joueurs."
L.ROTATION_BOSS_OVERALL    = "Général (tous les boss)"
L.ROTATION_MPLUS_BOSSES    = "Mythique+ : boss"
L.ROTATION_MPLUS_TRASH     = "Mythique+ : patrouilles / adds (AoE)"
L.ROTATION_SUBTITLE_MPLUS  = "Ce que les meilleurs joueurs utilisent dans %s, analysé à partir de %d pulls de donjons Mythiques+ de haut niveau par %d joueurs."
L.ROTATION_HINT            = "Classé par la rapidité avec laquelle les meilleurs joueurs lancent chaque sort dès qu'il est disponible, suivi des consommateur de ressources, puis du reste. Survolez une icône pour voir le sort et son utilisation par les meilleurs joueurs."
L.ROTATION_DATA_AGE        = "Lu sur le patch %s, %s."
L.ROTATION_NO_DATA         = "Aucune donnée de priorité pour cette spécialisation."
L.ROTATION_OTHER_TREE      = "Trop peu de joueurs de premier plan jouent en %s pour extraire une rotation, voici donc celle de %s."
L.ROTATION_COL_OPENER      = "Ouverture"
L.ROTATION_COL_CORE        = "Rotation principale"
L.ROTATION_COL_PRIORITY    = "Priorité"
L.ROTATION_PRIO_PROC       = "Quand %s est actif"
L.ROTATION_PRIO_STACKS     = "(à %d cumuls)"
L.ROTATION_PRIO_FILLER     = "Remplissage : lancer lorsque rien d'autre n'est disponible"
L.ROTATION_COL_FILLER      = "Remplissage"
L.ROTATION_COL_CDS         = "Quand utiliser les CDs"
L.ROTATION_SECTION_PRESSES = "Bases de la rotation"
L.ROTATION_SECTION_PROCS   = "Interactions et procs"
L.ROTATION_SHARES          = "%d%% des lancements, %d%% des dégâts"
L.ROTATION_SHARES_HEALER   = "%d%% des lancements, %d%% des soins"
L.ROTATION_HEALER_OPENER   = "Les soigneurs n'ont pas d'ouverture fixe. Commencez selon les besoins du pull."
L.ROTATION_HEALER_CDS      = "Les sorts de soins importants suivent les dégâts du boss et non un timing fixe, ils ne peuvent donc pas être lus automatiquement dans les logs. Planifiez-les combat par combat."
L.ROTATION_KIND_COOLDOWN   = "À lancer dès que possible, toutes les %s environ"
L.ROTATION_KIND_SPENDER    = "Dépenseur de ressource"
L.ROTATION_KIND_SPENDER_AT = "Dépenseur, généralement lancé avec %s en réserve"
L.ROTATION_KIND_PROC       = "Uniquement avec %s"
L.ROTATION_READY_NOW       = "Lancé dès qu'il est disponible"
L.ROTATION_READY_WAIT      = "Lancé environ %s après qu'il soit disponible"
L.ROTATION_EMPOWER_RANK    = "Relâcher au rang %s"
L.ROTATION_PROC_FROM       = "%s provient de %s." -- buff, then the press or presses that give it
L.ROTATION_AND             = " et "
L.ROTATION_PROC_RANDOM     = "%s se déclenche de manière autonome."
L.ROTATION_PROC_BY         = "À dépenser avec %s."
L.ROTATION_PROC_STACKS     = "Monter d'abord à %d cumuls."
L.ROTATION_FILLER_HINT     = "À lancer quand rien d'autre n'est prêt."
L.ROTATION_FILLER_NONE     = "Pas de réel sort de remplissage. Maintenez la rotation principale."
L.ROTATION_CDS_NONE        = "Aucun temps de recharge long dans cette rotation."
L.ROTATION_CD_ON_PULL      = "Au pull"
L.ROTATION_CD_FIRST_AT     = "Premier lancement à environ %s"
L.ROTATION_CD_TIMING       = "%s, puis toutes les %s environ"
L.ROTATION_CD_TIMING_ONCE  = "%s, une fois par combat"
L.ROTATION_CD_TOGETHER     = "À lancer en même temps que :"
L.ROTATION_CD_INSIDE       = "À conserver pour sa fenêtre :"
L.ROTATION_ITEMS_OPENER    = "La potion et le bijou actif s'utilisent avec vos temps de recharge."
L.ROTATION_ITEMS_CD        = "La potion et le bijou actif s'utilisent ici."
L.ROTATION_SECONDS         = "%d s"
L.ROTATION_MINUTES         = "%s min"
L.ROTATION_TIP_OPENER      = "%d%% des meilleurs joueurs lancent ceci ici."
L.ROTATION_TIP_BUFF        = "Actif %d%% du combat, dépensé environ %d fois par combat."
L.ROTATION_TIP_CD          = "Les meilleurs joueurs l'utilisent environ %s fois par combat."
L.OPTIONS_SHOW_MINIMAP     = "Afficher l'icône de la minicarte"
L.OPTIONS_COLORBLIND       = "Icônes adaptées aux daltoniens"
L.OPTIONS_ROW_SIZE         = "Taille des lignes Recommended Stats"
L.OPTIONS_SKIN             = "Apparence"
L.SKIN_DEFAULT = "Par défaut"
L.SKIN_CLASS   = "Couleur de classe"
L.SKIN_CUSTOM  = "Couleur personnalisée"
L.OPTIONS_EXPORT_SKIN = "Export. apparence"
L.OPTIONS_IMPORT_SKIN = "Import. apparence"
L.OPTIONS_DISCLAIMER = "Recommended Stats ne fera pas de vous un meilleur joueur par lui-même \226\128\148 il vous aide simplement à atteindre les statistiques adaptées à votre spécialisation."

--------------------------------------------------------------------------------
-- UI/MinimapButton.lua
--------------------------------------------------------------------------------
L.MINIMAP_TOOLTIP_LEFT  = "Clic gauche : afficher/masquer les panneaux"
L.MINIMAP_TOOLTIP_RIGHT = "Clic droit : options"

--------------------------------------------------------------------------------
-- UI/CopyPopup.lua (generic fallback defaults — callers usually pass their own)
--------------------------------------------------------------------------------
L.COPY_APPLY            = "Appliquer"
L.COPY_APPLIED          = "Appliqué."
L.COPY_SOMETHING_WRONG  = "Une erreur s'est produite."

--------------------------------------------------------------------------------
-- UI/SkinShare.lua
--------------------------------------------------------------------------------
L.SKIN_EXPORT_TITLE = "Exporter l'apparence"
L.SKIN_EXPORT_HINT  = "Copiez ce code et partagez-le (Ctrl+A, Ctrl+C) :"
L.SKIN_IMPORT_TITLE = "Importer l'apparence"
L.SKIN_IMPORT_HINT  = "Collez un code d'apparence RecommendedStats :"
L.SKIN_ERR_NOT_A_CODE   = "Ce n'est pas un code d'apparence RecommendedStats valide."
L.SKIN_ERR_BAD_COLOR    = "Le code d'apparence personnalisé comporte des données de couleur manquantes ou invalides."
L.SKIN_ERR_UNRECOGNIZED = "Apparence \"%s\" non reconnue."
L.SKIN_APPLIED          = "Apparence appliquée."

--------------------------------------------------------------------------------
-- UI/RatingNudge.lua
--------------------------------------------------------------------------------
L.RATING_NUDGE_TITLE = "Vous appréciez RecommendedStats ?"
L.RATING_NUDGE_HINT  = "Si l'addon vous est utile, une note sur CurseForge nous aide énormément :"

--------------------------------------------------------------------------------
-- RecommendedStats Analyzer link (Rotation window "My pulls" button, /rs link)
--------------------------------------------------------------------------------
L.ANALYZER_BUTTON     = "Mes combats"
L.ANALYZER_BUTTON_TIP = "Comparez vos pulls de raid avec les meilleurs joueurs de votre spécialisation sur rs.ctrlshiftzed.com : lancements, temps de recharge et buffs, analysés à partir de vos Warcraft Logs."
L.ANALYZER_TITLE      = "Vos essais en raid vs les meilleurs joueurs"
L.ANALYZER_HINT       = "Appuyez sur Ctrl+C pour copier, puis collez le lien dans votre navigateur. Vos combats doivent être enregistrés sur Warcraft Logs."
