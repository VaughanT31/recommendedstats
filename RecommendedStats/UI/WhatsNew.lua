-- RecommendedStats :: UI/WhatsNew.lua
-- Small popup shown once per real feature release — NOT the automated twice-weekly data
-- refresh (see Core.lua's RS:AnnounceDataUpdateIfNew for that, a chat line instead of a
-- popup). Add a new entry to ANNOUNCEMENTS below whenever you ship an actual feature; the
-- popup only fires again once the newest entry's id differs from what the player last
-- dismissed, so routine data-only builds (which never touch this file) can't re-trigger it.

local RS = RecommendedStats
local L = RecommendedStats_Locale

local ANNOUNCEMENTS = {
    {
        id = "2026-08-27-skins",
        title = "What's New in RecommendedStats",
        lines = {
            "Skins: pick a Class Color or Custom Color accent from Options, and export/import a code to share your look.",
            "The minimap button is now a real LibDataBroker icon, so minimap-button-organizer addons can manage it.",
            "Window/minimap positions are now remembered per character instead of shared account-wide.",
            "You'll now see a chat note whenever fresh stat/BiS data lands.",
        },
    },
    {
        id = "2026-09-22-scoped-talents",
        title = "What's New in RecommendedStats",
        lines = {
            "Talents window: pick a specific Mythic+ dungeon or raid boss from the dropdown to see the build top players actually run there, not just an overall spec build.",
            "Falls back to your spec's overall build automatically wherever a specific dungeon/boss doesn't have enough sampled players yet.",
        },
    },
    {
        id = "2026-09-30-rotation",
        title = "What's New in RecommendedStats",
        lines = {
            "New Rotation window: the opener, the core loop, the filler and when to use cooldowns for your spec and hero talents, read from what top players actually press on raid bosses.",
            "It shows which press gives each proc and which press spends it, and how many stacks to build first. Hover any icon for the spell's tooltip.",
            "Pick a raid boss from the dropdown to see how it is played on that fight, or leave it on Overall.",
            "The panel tabs are now Stats, BiS, Talents and Rotation.",
        },
    },
    {
        id = "2026-10-05-bis-window",
        title = "What's New in RecommendedStats",
        lines = {
            "BiS now opens its own window, like Talents and Rotation, with your gear in two columns and full item names.",
            "Each item's secondary stats are listed one per line, with the recommended enchant and gem beside them.",
            "Its Raid / Mythic+ toggle follows the same setting as the Stats panel. Type /rs bis to open it directly.",
        },
    },
}

local function LatestAnnouncement()
    return ANNOUNCEMENTS[#ANNOUNCEMENTS]
end

function RS:GetLastSeenAnnouncement()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.lastSeenAnnouncement
end

local function MarkSeen(id)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.lastSeenAnnouncement = id
end

--------------------------------------------------------------------------------
-- Popup frame (built lazily — most sessions never need it, since it's only shown
-- once per feature release rather than every login)
--------------------------------------------------------------------------------
local POPUP_W = 360
local PAD = 14

local popup

local function EnsurePopup()
    if popup then return end

    popup = CreateFrame("Frame", "RecommendedStatsWhatsNew", UIParent, "BackdropTemplate")
    popup:SetWidth(POPUP_W)
    popup:SetPoint("TOP", UIParent, "TOP", 0, -140)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.043, 0.047, 0.063, 0.97)
    popup:SetBackdropBorderColor(0.25, 0.27, 0.33, 0.7)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOPLEFT", PAD, -PAD)
    -- Explicit width, not anchor-derived (SetPoint on both sides only resolves its wrap width
    -- on the NEXT layout pass, not synchronously) — ShowIfUnseen below reads GetStringHeight()
    -- immediately after SetText() in the same call, so an anchor-derived width read stale/
    -- unwrapped geometry there and undersized the popup, letting the Got It button land on
    -- top of the actual (taller) wrapped text instead of below it.
    popup.title:SetWidth(POPUP_W - PAD - 30)
    popup.title:SetJustifyH("LEFT")

    popup.body = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.body:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -10)
    popup.body:SetWidth(POPUP_W - PAD - PAD) -- see popup.title's SetWidth comment above
    popup.body:SetJustifyH("LEFT")
    popup.body:SetSpacing(4)

    popup.close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.close:SetPoint("TOPRIGHT", 2, 2)

    popup.gotIt = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.gotIt:SetSize(80, 22)
    popup.gotIt:SetPoint("BOTTOM", 0, 12)
    popup.gotIt:SetText(L.GOT_IT)

    local function Dismiss()
        MarkSeen(LatestAnnouncement().id)
        popup:Hide()
    end
    popup.close:SetScript("OnClick", Dismiss)
    popup.gotIt:SetScript("OnClick", Dismiss)
end

local function ShowIfUnseen()
    local latest = LatestAnnouncement()
    if not latest or RS:GetLastSeenAnnouncement() == latest.id then return end

    EnsurePopup()
    popup.title:SetText(latest.title)
    popup.body:SetText(table.concat(latest.lines, "\n\n"))

    -- GetStringHeight() (not a hand-counted line count) so the frame fits correctly however
    -- many lines a given release's entry has, wrapped or not.
    popup:SetHeight(14 + popup.title:GetStringHeight() + 10 + popup.body:GetStringHeight() + 12 + 22 + 14)
    popup:Show()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", ShowIfUnseen)
