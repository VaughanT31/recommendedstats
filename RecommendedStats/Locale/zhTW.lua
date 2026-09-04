-- RecommendedStats :: Locale/zhTW.lua
-- Translation provided by BlueNightSky (三皈依-暗影之月@TW)
-- Loaded after Locale/enUS.lua (see the .toc) and only takes effect for a zhTW client.

if GetLocale() ~= "zhTW" then return end

RecommendedStats_Locale = RecommendedStats_Locale or {}
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Shared chrome (tabs, generic fallbacks, "Got it" reused across popups)
--------------------------------------------------------------------------------
L.CHAT_PREFIX     = "|cff33ff99屬性建議|r"
L.ADDON_TITLE     = "屬性建議"
L.TAB_STATS       = "屬性建議"
L.TAB_BIS         = "最佳裝備"
L.SELECT          = "選擇"
L.GOT_IT          = "知道了"
L.SCHEMA_OUT_OF_DATE = "此插件版本的屬性數據已過時，請更新。"

--------------------------------------------------------------------------------
-- Core.lua — slash command / chat messages (appended to L.CHAT_PREFIX)
--------------------------------------------------------------------------------
L.MSG_CONTENT_SET      = " 內容設定為 %s"
-- Fixed from the submitted "已於 % 更新" (a bare % isn't a valid format specifier) to "%s" —
-- this string is formatted with 3 arguments (date, sample size, patch) and needs 3 matching
-- conversions or Lua's string.format throws a hard error the moment this actually fires.
L.MSG_DATA_REFRESHED   = " 屬性目標以及最佳裝備已於 %s 更新（排名前%d的玩家，版本 %s）。"
L.MSG_POSITIONS_RESET  = " 面板位置重置。拖曳面板來重新移動。"
L.MSG_CONTENT_STATUS   = " 內容 = %s  (使用 /rs raid|mythicplus|resetpos|options|skin export|skin import)"

--------------------------------------------------------------------------------
-- UI/CharacterPanel.lua
--------------------------------------------------------------------------------
L.STATUS_UNDER    = "太低"
L.STATUS_ON       = "達標"
L.STATUS_OVER     = "過多"
L.STATUS_SECRET   = "此無法比對"
L.STATUS_UNDER_CB  = "[v] 太低"
L.STATUS_ON_CB     = "[=] 達標"
L.STATUS_OVER_CB   = "[^] 過多"
L.STATUS_SECRET_CB = "[?] 此無法比對"

L.STAT_HASTE       = "加速"
L.STAT_CRIT        = "致命一擊"
L.STAT_MASTERY     = "精通"
L.STAT_VERSATILITY = "臨機應變"
L.STAT_HASTE_SHORT       = "加速"
L.STAT_CRIT_SHORT        = "致命"
L.STAT_MASTERY_SHORT     = "精通"
L.STAT_VERSATILITY_SHORT = "臨機"

L.CONTENT_RAID       = "團隊"
L.CONTENT_MYTHICPLUS = "傳奇+"

L.SIZE_DEFAULT = "預設"
L.SIZE_SMALL   = "小"
L.SIZE_MEDIUM  = "中"
L.SIZE_LARGE   = "大"

L.NO_TARGETS_YET = "您目前的專精+內容還沒有屬性目標。"
L.FOOTER_SAMPLE_OF_TARGET = "%d的%d玩家"
L.FOOTER_TOP_N            = "頂尖的%d玩家"
L.FOOTER_LINE             = "目標: %s \194\183 %s \194\183 已更新於 %s"
L.FOOTER_MAYBE_STALE      = " (可能已經過時了)"
L.TARGET_INLINE           = "目標 %.0f%%"
L.DELTA_FROM_TARGET       = "%+.1f%% 目標差距"
L.PRIORITY_LINE           = "最優先: %s"

--------------------------------------------------------------------------------
-- UI/BiSWindow.lua
--------------------------------------------------------------------------------
L.SLOT_HEAD      = "頭"
L.SLOT_NECK      = "項鍊"
L.SLOT_SHOULDER  = "肩"
L.SLOT_BACK      = "披風"
L.SLOT_CHEST     = "胸"
L.SLOT_WRIST     = "手腕"
L.SLOT_HANDS     = "手"
L.SLOT_WAIST     = "腰"
L.SLOT_LEGS      = "腿"
L.SLOT_FEET      = "腳"
L.SLOT_FINGER_1  = "戒指 1"
L.SLOT_FINGER_2  = "戒指 2"
L.SLOT_TRINKET_1 = "飾品 1"
L.SLOT_TRINKET_2 = "飾品 2"
L.SLOT_MAIN_HAND = "主手"
L.SLOT_OFF_HAND  = "副手"

L.DIFFICULTY_HEROIC = "英雄"
L.DIFFICULTY_NORMAL = "普通"

L.NEW_TAG = "NEW"
L.NO_BIS_DATA_YET = "您目前的專精+內容還沒有最佳裝備數據。"
L.BIS_PCT_FALLBACK   = "頂尖的 %d %% \194\183 %s (尚未有傳奇紀錄)"
L.BIS_PCT_LOW_SAMPLE = "頂尖的 %d %% (比平常少)"
L.BIS_PCT_PLAIN      = "頂尖的 %d %%"
L.BIS_TIER_LINE      = "套裝: %d/4 \194\183 %d%% 運行四件"
L.BIS_SOURCE_PREFIX  = "來源: "
L.BIS_SOURCE_WITH_DIFFICULTY = "%s (%s)"
L.BIS_ENCHANT_LABEL = "附魔 "
L.BIS_GEM_LABEL     = "寶石 "

--------------------------------------------------------------------------------
-- UI/OptionsPanel.lua
--------------------------------------------------------------------------------
L.OPTIONS_WINDOW_POSITION  = "視窗位置"
L.ATTACH_MODE_ATTACHED = "與角色視窗連動"
L.ATTACH_MODE_FREE     = "不連動 (自由移動)"
L.OPTIONS_SHOW_STATS_TAB   = "顯示 \"屬性建議\" 標籤"
L.OPTIONS_SHOW_BIS_TAB     = "顯示 \"最佳裝備\" 標籤"
L.OPTIONS_SHOW_MINIMAP     = "顯示小地圖按鈕"
L.OPTIONS_COLORBLIND       = "色盲友善的圖示"
L.OPTIONS_ROW_SIZE         = "屬性建議行列大小"
L.OPTIONS_SKIN             = "外觀"
L.SKIN_DEFAULT = "預設"
L.SKIN_CLASS   = "職業顏色"
L.SKIN_CUSTOM  = "自訂顏色"
L.OPTIONS_EXPORT_SKIN = "匯出外觀"
L.OPTIONS_IMPORT_SKIN = "匯入外觀"
L.OPTIONS_DISCLAIMER = "屬性建議本身不會讓你獲得更多DPS \226\128\148 它只是幫助您達到適合您專精的正確屬性權重。"

--------------------------------------------------------------------------------
-- UI/MinimapButton.lua
--------------------------------------------------------------------------------
L.MINIMAP_TOOLTIP_LEFT  = "左鍵點擊: 顯示/隱藏面板"
L.MINIMAP_TOOLTIP_RIGHT = "右鍵點擊: 選項"

--------------------------------------------------------------------------------
-- UI/CopyPopup.lua (generic fallback defaults — callers usually pass their own)
--------------------------------------------------------------------------------
L.COPY_APPLY            = "套用"
L.COPY_APPLIED          = "已套用。"
L.COPY_SOMETHING_WRONG  = "出了點問題。"

--------------------------------------------------------------------------------
-- UI/SkinShare.lua
--------------------------------------------------------------------------------
L.SKIN_EXPORT_TITLE = "匯出外觀"
L.SKIN_EXPORT_HINT  = "複製此代碼並分享 (Ctrl+A, Ctrl+C):"
L.SKIN_IMPORT_TITLE = "匯入外觀"
L.SKIN_IMPORT_HINT  = "貼上屬性建議的外觀代碼:"
L.SKIN_ERR_NOT_A_CODE   = "非屬性建議的外觀代碼。"
L.SKIN_ERR_BAD_COLOR    = "自訂外觀代碼是缺少/無效的顏色數據。"
L.SKIN_ERR_UNRECOGNIZED = "無法辨識的外觀 \"%s\"."
L.SKIN_APPLIED          = "外觀已套用。"

--------------------------------------------------------------------------------
-- UI/RatingNudge.lua
--------------------------------------------------------------------------------
L.RATING_NUDGE_TITLE = "喜歡屬性建議嗎？"
L.RATING_NUDGE_HINT  = "如果它有用，CurseForge上的評論會有很大幫助:"
