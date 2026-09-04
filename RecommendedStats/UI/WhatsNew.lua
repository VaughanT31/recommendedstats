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
local POPUP_W = 320

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
    popup.title:SetPoint("TOPLEFT", 14, -14)
    popup.title:SetPoint("TOPRIGHT", -30, -14)
    popup.title:SetJustifyH("LEFT")

    popup.body = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.body:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -10)
    popup.body:SetPoint("RIGHT", -14, 0)
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
    popup.body:SetText(table.concat(latest.lines, "\n"))

    -- GetStringHeight() (not a hand-counted line count) so the frame fits correctly however
    -- many lines a given release's entry has, wrapped or not.
    popup:SetHeight(14 + popup.title:GetStringHeight() + 10 + popup.body:GetStringHeight() + 12 + 22 + 14)
    popup:Show()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", ShowIfUnseen)
