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
L.TAB_STATS       = "Recommended Stats"
L.TAB_BIS         = "BiS Gear"
L.SELECT          = "Select"
L.GOT_IT          = "Got it"
L.SCHEMA_OUT_OF_DATE = "Stat data is out of date for this addon version. Please update."

--------------------------------------------------------------------------------
-- Core.lua — slash command / chat messages (appended to L.CHAT_PREFIX)
--------------------------------------------------------------------------------
L.MSG_CONTENT_SET      = " content set to %s"
L.MSG_DATA_REFRESHED   = " stat targets and BiS gear were refreshed on %s (top %d players, patch %s)."
L.MSG_POSITIONS_RESET  = " panel positions reset. Drag a panel to move it again."
L.MSG_CONTENT_STATUS   = " content = %s  (use /rs raid|mythicplus|resetpos|options|skin export|skin import)"

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
L.DELTA_FROM_TARGET       = "%+.1f%% from target"
L.DELTA_FROM_TARGET_WITH_RATING = "%+.0f (%+.1f%%) from target"
L.PRIORITY_LINE           = "Priority: %s"

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
L.OPTIONS_SHOW_STATS_TAB   = "Show \"Recommended Stats\" tab"
L.OPTIONS_SHOW_BIS_TAB     = "Show \"BiS Gear\" tab"
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
