-- RecommendedStats :: UI/RatingNudge.lua
-- One-time (ever, not per-release) nudge toward rating the addon on CurseForge, shown after a
-- handful of real logins (RS:BumpLoginCount() in Core.lua, incremented only on a true login —
-- see PLAYER_ENTERING_WORLD's isInitialLogin arg there, not /reload) so a brand-new install
-- isn't asked before the player has formed an opinion. Copy-link based since WoW addons can't
-- open a browser directly.

local RS = RecommendedStats

local LOGIN_THRESHOLD = 5
local CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/recommended-stats"

local function MarkSeen()
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.ratingNudgeShown = true
end

local function MaybeShow()
    RecommendedStatsDB = RecommendedStatsDB or {}
    if RecommendedStatsDB.ratingNudgeShown then return end
    if (RecommendedStatsDB.loginCount or 0) < LOGIN_THRESHOLD then return end

    RS:ShowCopyPopup({
        title = "Enjoying RecommendedStats?",
        hint = "If it's been useful, a rating on CurseForge helps a lot:",
        text = CURSEFORGE_URL,
        buttonText = "Got it",
        onAction = MarkSeen,
        onClose = MarkSeen, -- dismissing via X/Escape counts as "seen" too, not just the button
    })
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", MaybeShow)
