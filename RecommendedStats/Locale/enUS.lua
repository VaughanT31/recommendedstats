-- RecommendedStats :: Locale/enUS.lua
-- Base locale table. Loaded first (see the .toc), before Data/*.lua and every UI file, so
-- everything after it can do `local L = RecommendedStats_Locale`.
--
-- Extension point for a future translation: add a new Locale/<locale>.lua file, loaded AFTER
-- this one in the .toc, guarded like:
--   if GetLocale() ~= "deDE" then return end
--   local L = RecommendedStats_Locale
--   L.TAB_STATS = "..."   -- only override the keys that locale actually translates
-- No other locale ships today — this file is the only one, and every key below is the enUS text
-- used regardless of client locale until a translation file like that exists.

RecommendedStats_Locale = RecommendedStats_Locale or {}
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Shared chrome (tabs, generic fallbacks, "Got it" reused across popups)
--------------------------------------------------------------------------------
L.CHAT_PREFIX     = "|cff33ff99RecommendedStats|r"
L.ADDON_TITLE     = "Recommended Stats"
-- Short on purpose: the panel header holds four equal buttons (Stats, BiS, Talents, Rotation).
L.TAB_STATS       = "Stats"
L.TAB_BIS         = "BiS"
L.SELECT          = "Select"
L.GOT_IT          = "Got it"
L.SCHEMA_OUT_OF_DATE = "Stat data is out of date for this addon version. Please update."

--------------------------------------------------------------------------------
-- Core.lua — slash command / chat messages (appended to L.CHAT_PREFIX)
--------------------------------------------------------------------------------
L.MSG_CONTENT_SET      = " content set to %s"
L.MSG_DATA_REFRESHED   = " stat targets and BiS gear were refreshed on %s (top %d players, patch %s)."
L.MSG_POSITIONS_RESET  = " panel positions reset. Drag a panel to move it again."
L.MSG_CONTENT_STATUS   = " content = %s  (use /rs raid|mythicplus|bis|talents|rotation|link|resetpos|options|skin export|skin import)"

--------------------------------------------------------------------------------
-- UI/CharacterPanel.lua
--------------------------------------------------------------------------------
L.STATUS_UNDER    = "Too low"
L.STATUS_ON       = "On target"
L.STATUS_OVER     = "Over \194\183 fine"
L.STATUS_SECRET   = "Can't compare here"
-- Colorblind-mode variants (RS:GetColorblindMode()) — shape glyph prefixed onto the same text.
-- Plain ASCII/bracket glyphs only: WoW's default client fonts (FRIZQT__.ttf etc.) don't cover the
-- Unicode geometric-shapes block, so a real triangle/circle character (▼●▲) renders as a tofu box
-- — confirmed live. The interpunct used elsewhere (\194\183, U+00B7) is Latin-1 Supplement and
-- renders fine, but that's the extent of what's safe to rely on without shipping a custom font.
L.STATUS_UNDER_CB  = "[v] Too low"
L.STATUS_ON_CB     = "[=] On target"
L.STATUS_OVER_CB   = "[^] Over \194\183 fine"
L.STATUS_SECRET_CB = "[?] Can't compare here"

L.STAT_HASTE       = "Haste"
L.STAT_CRIT        = "Critical Strike"
L.STAT_MASTERY     = "Mastery"
L.STAT_VERSATILITY = "Versatility"
L.STAT_HASTE_SHORT       = "Haste"
L.STAT_CRIT_SHORT        = "Crit"
L.STAT_MASTERY_SHORT     = "Mastery"
L.STAT_VERSATILITY_SHORT = "Vers"

L.CONTENT_RAID       = "Raid"
L.CONTENT_MYTHICPLUS = "Mythic+"

L.SIZE_DEFAULT = "Default"
L.SIZE_SMALL   = "Small"
L.SIZE_MEDIUM  = "Medium"
L.SIZE_LARGE   = "Large"

L.NO_TARGETS_YET = "No stat targets for your current spec + content yet."
L.FOOTER_SAMPLE_OF_TARGET = "%d of %d players"
L.FOOTER_TOP_N            = "top %d players"
L.FOOTER_LINE             = "Targets: %s \194\183 %s \194\183 updated %s"
L.FOOTER_MAYBE_STALE      = " (may be stale)"
L.CURRENT_VALUE           = "%.1f%%"
L.CURRENT_VALUE_WITH_RATING = "%d (%.1f%%)"
L.TARGET_INLINE           = "target %.0f%%"
L.TARGET_WITH_RATING      = "target %.0f (%.0f%%)"
-- "high" is the 90th-percentile reading among top players (RecommendedStatsNode's aggregate.js),
-- shown alongside the median target so a player can see how spread out top players actually are
-- rather than just chasing a single number — e.g. mastery can have a wide real spread even though
-- the median target looks tight. Omitted (falls back to TARGET_INLINE/TARGET_WITH_RATING above)
-- whenever a key has no "*High" field yet (data built before this existed).
L.TARGET_WITH_HIGH        = "target %.0f%% \194\183 top %.0f%%"
L.TARGET_WITH_RATING_AND_HIGH = "target %.0f (%.0f%%) \194\183 top %.0f%%"
L.DELTA_FROM_TARGET       = "%+.1f%% from target"
L.DELTA_FROM_TARGET_WITH_RATING = "%+.0f (%+.1f%%) from target"
L.PRIORITY_LINE           = "Priority: %s"
L.PRIORITY_TOOLTIP        = "Ranked by how tightly top players' values cluster for each stat, not a simulated combat value. A stat most players converge on is shown first; one with wide spread is shown last."
L.TREND_SINCE_LOGIN       = "Since last login (%s): %+.1f%%"

--------------------------------------------------------------------------------
-- UI/BiSWindow.lua
--------------------------------------------------------------------------------
L.SLOT_HEAD      = "Head"
L.SLOT_NECK      = "Neck"
L.SLOT_SHOULDER  = "Shoulder"
L.SLOT_BACK      = "Back"
L.SLOT_CHEST     = "Chest"
L.SLOT_WRIST     = "Wrist"
L.SLOT_HANDS     = "Hands"
L.SLOT_WAIST     = "Waist"
L.SLOT_LEGS      = "Legs"
L.SLOT_FEET      = "Feet"
L.SLOT_FINGER_1  = "Ring 1"
L.SLOT_FINGER_2  = "Ring 2"
L.SLOT_TRINKET_1 = "Trinket 1"
L.SLOT_TRINKET_2 = "Trinket 2"
L.SLOT_MAIN_HAND = "Main Hand"
L.SLOT_OFF_HAND  = "Off Hand"

L.DIFFICULTY_HEROIC = "Heroic"
L.DIFFICULTY_NORMAL = "Normal"

L.NEW_TAG = "NEW"
L.NO_BIS_DATA_YET = "No BiS data for your current spec + content yet."
L.BIS_PCT_FALLBACK   = "%% of top %d \194\183 %s (no Mythic logs yet)"
L.BIS_PCT_LOW_SAMPLE = "%% of top %d (fewer than usual)"
L.BIS_PCT_PLAIN      = "%% of top %d"
L.BIS_TIER_LINE      = "Tier: %d/4 \194\183 %d%% run 4pc"
L.BIS_WINDOW_TITLE   = "BiS Gear | %s"
L.BIS_WINDOW_HINT    = "Shift-click: link in chat \194\183 Ctrl-click: preview"
L.BIS_SOURCE_PREFIX  = "Source: "
L.BIS_SOURCE_WITH_DIFFICULTY = "%s (%s)"
L.BIS_ENCHANT_LABEL = "Enchant "
L.BIS_GEM_LABEL     = "Gem "
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
L.OPTIONS_WINDOW_POSITION  = "Window position"
L.ATTACH_MODE_ATTACHED = "Attach to Character Screen"
L.ATTACH_MODE_FREE     = "Not attached (move freely)"
L.OPTIONS_SHOW_STATS_TAB   = "Show \"Stats\" tab"
L.OPTIONS_SHOW_BIS_TAB     = "Show \"BiS\" button"

--------------------------------------------------------------------------------
-- UI/TalentsWindow.lua, Talents.lua
--------------------------------------------------------------------------------
L.TALENTS_BUTTON            = "Talents"
L.TALENTS_SCOPE_OVERALL     = "Overall (all bosses / dungeons)"
L.TALENTS_SCOPE_FALLBACK    = "%s (overall build)"
L.TALENTS_SCOPE_DIFFICULTY  = "%s (%s)"
L.TALENTS_COPY_LONG         = "Copy loadout string"
L.TALENTS_SRC_OVERALL       = "Spec-wide build from top players"
L.TALENTS_SRC_RAID          = "%s kills of this boss"
L.TALENTS_SRC_RAID_LOWER    = "%s kills of this boss (too few higher-difficulty kills)"
L.TALENTS_SRC_DUNGEON       = "Top runs in this dungeon"
L.TALENTS_SRC_CURRENT_RAID  = "Current builds of top %s parsers on this boss (not the exact kill build)"
L.TALENTS_SRC_CURRENT_DUNGEON = "Current builds of top players in this dungeon (not the exact run build)"
L.TALENTS_SRC_FALLBACK      = "Not enough data for this one yet, showing the spec-wide build"
L.TALENTS_SAMPLE            = "Based on %d players, %d different builds"
L.TALENTS_NO_DATA          = "No talent data for this spec yet."
L.TALENTS_NOT_READY         = "Talent info isn't available yet. Try again in a moment."
L.TALENTS_DECODE_FAILED     = "Couldn't read this talent data. It may be for a different game version."
L.TALENTS_TREE_TITLE        = "%s | %s"
L.TALENTS_TREE_HINT         = "Gold = in this build (the real build closest to what most players take). Hover a talent for pick rates."
L.TALENTS_PICKED_BY         = "Picked by %d%% of players (%d of %d)"
L.TALENTS_OPTION_PICKED_BY  = "%s: %d%%"
L.TALENTS_COPY_TITLE        = "Talent loadout"
L.TALENTS_COPY_HINT         = "Copy this string, then use Import on the talents page."
L.TALENTS_DIFFICULTY = { mythic = "Mythic", heroic = "Heroic", normal = "Normal" }

--------------------------------------------------------------------------------
-- UI/RotationWindow.lua
--------------------------------------------------------------------------------
L.ROTATION_BUTTON          = "Rotation"
L.ROTATION_TITLE           = "%s | Rotation"
L.ROTATION_TITLE_TREE      = "%s | Rotation | %s"
L.ROTATION_SUBTITLE        = "What top players press, read from %d %s raid kills by %d players, all bosses pooled."
L.ROTATION_SUBTITLE_BOSS   = "What top players press on %s, read from %d %s kills by %d players."
L.ROTATION_BOSS_OVERALL    = "Overall (all bosses)"
L.ROTATION_HINT            = "Hover any icon for the spell and how top players use it."
L.ROTATION_DATA_AGE        = "Read on patch %s, %s."
L.ROTATION_NO_DATA         = "No rotation data for this spec yet."
L.ROTATION_OTHER_TREE      = "Too few top players run %s to read a rotation from, so this is %s."
L.ROTATION_COL_OPENER      = "Opener"
L.ROTATION_COL_CORE        = "Mid Rotation"
L.ROTATION_COL_FILLER      = "Filler"
L.ROTATION_COL_CDS         = "When to use CDs"
L.ROTATION_SECTION_PRESSES = "What the rotation is built on"
L.ROTATION_SECTION_PROCS   = "What feeds what"
L.ROTATION_SHARES          = "%d%% of presses, %d%% of damage"
L.ROTATION_SHARES_HEALER   = "%d%% of presses, %d%% of healing"
L.ROTATION_HEALER_OPENER   = "Healers have no set opener. Start with what the pull needs."
L.ROTATION_HEALER_CDS      = "Healing cooldowns follow the boss's damage, not a fixed timing, so they can't be read from logs. Plan them per fight."
L.ROTATION_KIND_COOLDOWN   = "Press on cooldown, about every %s"
L.ROTATION_KIND_SPENDER    = "Spender"
L.ROTATION_KIND_SPENDER_AT = "Spender, usually pressed with %s banked"
L.ROTATION_KIND_PROC       = "Only with %s"
L.ROTATION_EMPOWER_RANK    = "Release at rank %s"
L.ROTATION_PROC_FROM       = "%s comes from %s." -- buff, then the press or presses that give it
L.ROTATION_AND             = " and "
L.ROTATION_PROC_RANDOM     = "%s procs on its own."
L.ROTATION_PROC_BY         = "Spend it with %s."
L.ROTATION_PROC_STACKS     = "Build to %d stacks first."
L.ROTATION_FILLER_HINT     = "Press when nothing else is ready."
L.ROTATION_FILLER_NONE     = "No real filler. Keep the mid rotation rolling."
L.ROTATION_CDS_NONE        = "No long cooldowns in this rotation."
L.ROTATION_CD_ON_PULL      = "On the pull"
L.ROTATION_CD_FIRST_AT     = "First at about %s"
L.ROTATION_CD_TIMING       = "%s, then about every %s"
L.ROTATION_CD_TIMING_ONCE  = "%s, once a fight"
L.ROTATION_CD_TOGETHER     = "Press together with:"
L.ROTATION_CD_INSIDE       = "Save for its window:"
L.ROTATION_ITEMS_OPENER    = "Potion and on-use trinket go in with your cooldowns."
L.ROTATION_ITEMS_CD        = "Potion and on-use trinket go here."
L.ROTATION_SECONDS         = "%d sec"
L.ROTATION_MINUTES         = "%s min"
L.ROTATION_TIP_OPENER      = "%d%% of top players press this here."
L.ROTATION_TIP_BUFF        = "Up %d%% of the fight, spent about %d times a fight."
L.ROTATION_TIP_CD          = "Top players use it about %s times a fight."
L.OPTIONS_SHOW_MINIMAP     = "Show minimap icon"
L.OPTIONS_COLORBLIND       = "Colorblind-friendly icons"
L.OPTIONS_ROW_SIZE         = "Recommended Stats row size"
L.OPTIONS_SKIN             = "Skin"
L.SKIN_DEFAULT = "Default"
L.SKIN_CLASS   = "Class Color"
L.SKIN_CUSTOM  = "Custom Color"
L.OPTIONS_EXPORT_SKIN = "Export Skin"
L.OPTIONS_IMPORT_SKIN = "Import Skin"
L.OPTIONS_DISCLAIMER = "Recommended Stats won't make you do more DPS by itself \226\128\148 it just helps you hit the correct stat weights for your spec."

--------------------------------------------------------------------------------
-- UI/MinimapButton.lua
--------------------------------------------------------------------------------
L.MINIMAP_TOOLTIP_LEFT  = "Left-click: show/hide panels"
L.MINIMAP_TOOLTIP_RIGHT = "Right-click: options"

--------------------------------------------------------------------------------
-- UI/CopyPopup.lua (generic fallback defaults — callers usually pass their own)
--------------------------------------------------------------------------------
L.COPY_APPLY            = "Apply"
L.COPY_APPLIED          = "Applied."
L.COPY_SOMETHING_WRONG  = "Something went wrong."

--------------------------------------------------------------------------------
-- UI/SkinShare.lua
--------------------------------------------------------------------------------
L.SKIN_EXPORT_TITLE = "Export Skin"
L.SKIN_EXPORT_HINT  = "Copy this code and share it (Ctrl+A, Ctrl+C):"
L.SKIN_IMPORT_TITLE = "Import Skin"
L.SKIN_IMPORT_HINT  = "Paste a RecommendedStats skin code:"
L.SKIN_ERR_NOT_A_CODE   = "Not a RecommendedStats skin code."
L.SKIN_ERR_BAD_COLOR    = "Custom skin code is missing/invalid color data."
L.SKIN_ERR_UNRECOGNIZED = "Unrecognized skin \"%s\"."
L.SKIN_APPLIED          = "Skin applied."

--------------------------------------------------------------------------------
-- UI/RatingNudge.lua
--------------------------------------------------------------------------------
L.RATING_NUDGE_TITLE = "Enjoying RecommendedStats?"
L.RATING_NUDGE_HINT  = "If it's been useful, a rating on CurseForge helps a lot:"

--------------------------------------------------------------------------------
-- RecommendedStats Analyzer link (Rotation window "My pulls" button, /rs link)
--------------------------------------------------------------------------------
L.ANALYZER_BUTTON     = "My pulls"
L.ANALYZER_BUTTON_TIP = "Compare your raid pulls with top players of your spec on rs.ctrlshiftzed.com: casts, cooldowns and buffs, read from your Warcraft Logs."
L.ANALYZER_TITLE      = "Your raid pulls vs the top players"
L.ANALYZER_HINT       = "Press Ctrl+C to copy, then paste it into your browser. Your raid needs to be logged on Warcraft Logs."
