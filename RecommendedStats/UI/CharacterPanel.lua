-- RecommendedStats :: UI/CharacterPanel.lua
-- Single merged window, tabbed between "Recommended Stats" (stat readout + Raid/Mythic+
-- dropdown) and "BiS Gear" (UI/BiSWindow.lua's content) — one physical frame, one drag/escape/
-- attach-mode lifecycle, instead of two separately-docked panels.
--
-- Depends on Core.lua providing:
--   RS:Evaluate()  -> { {name,current,target,delta,state}, ... }, key   (state = "under"|"on"|"over")
--   RS:GetContent() / RS:SetContent(c)                                  (c = "RAID"|"MYTHICPLUS")
--   RS:HasDataFor(c)                                                    -- greys out a dead-end dropdown choice
--   RS.listeners (table)  and  RS:Refresh()
--   RS:GetActiveTab() / RS:SetActiveTab(tab) / RS.tabSyncers            (tab = "STATS"|"BIS")
--   RS:GetShowStats() / RS:GetShowBiS()                                 (which tabs are enabled)
--   RS:IsDataStale()
--   RS:GetSampleSizeFor(key) / RS:IsSampleSizeLow(key)
--   RecommendedStatsData_Meta (sampleSize, gamePatch, updated)
--
-- Owns RS.bisPage: an empty content frame sized for BiS Gear's row count, created here and
-- populated by UI/BiSWindow.lua (see EnsurePanel below) — this file loads first per the .toc,
-- so RS.bisPage always exists before BiSWindow.lua's own visibilitySyncer runs.
--
-- NOTE: the dropdown uses the modern (11.x+/12.x) menu system
-- (DropdownButton + WowStyle1DropdownTemplate + SetupMenu). Verify the template
-- name resolves in your client; it is the current retail dropdown. The radio elements'
-- :SetEnabled(bool) (used below to grey out a dead-end Raid/Mythic+ choice) is part of the
-- same menu system — verify it actually dims/blocks the click in your client too.

local RS = RecommendedStats
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
-- 440, not the original 360 — grew once for BiS Gear's item-name truncation, then again for the
-- enchant/gem icon block between the slot label and the item. Shared with BiS Gear's row width
-- (UI/BiSWindow.lua).
local PANEL_W   = 440
local ROW_W     = PANEL_W - 24  -- content width inside the panel's side padding
-- The bar is anchored directly below the current-value text (see CreateRow's BAR_GAP), not
-- pinned to this row height's bottom edge, so a size's ROW_H only needs to be "tall enough to
-- hold its content + a little breathing room" — it's the row-to-row stride, not a box the
-- content is stretched to fill.
local ROW_GAP   = 8
local FOOTER_H  = 20
-- Extra row for the stat-priority line (RecommendedStatsData_StatWeights, from
-- RecommendedStatsNode/src/bloodmallet.js) — see StatsContentH()/EnsurePanel below.
local PRIORITY_H = 16
local BAR_H     = 8
local BAR_GAP   = 6 -- vertical gap between the current-value text (or combined line) and the bar below it

-- Row density, set from UI/OptionsPanel.lua (RS:GetStatsSize()/RS:SetStatsSize()):
--   DEFAULT — name + big value + bar (today's look)
--   SMALL   — one line, no bar at all
--   MEDIUM  — one line, with the bar directly beneath it
--   LARGE   — DEFAULT plus a "+X.X% from target" delta line under the bar
local ROW_H_BY_SIZE = { DEFAULT = 66, SMALL = 20, MEDIUM = 32, LARGE = 84 }
local function CurrentRowH()
    return ROW_H_BY_SIZE[RS:GetStatsSize()] or ROW_H_BY_SIZE.DEFAULT
end
local function StatsContentH()
    return (CurrentRowH() + ROW_GAP) * 4 + PRIORITY_H + FOOTER_H + 6
end

-- Shared header: 8px top pad + tab row + gap + dropdown row + 8px bottom pad. Both pages
-- (statsPage here, RS.bisPage from BiSWindow.lua) anchor their own top-left below this.
local TAB_H          = 24
local TAB_GAP        = 4
local DROPDOWN_ROW_H = 20
local HEADER_H       = 8 + TAB_H + 6 + DROPDOWN_ROW_H + 8

-- No more hand-typed height constant here — RS:GetBisContentHeight() (UI/BiSWindow.lua) computes
-- this from that file's own ROW_H/ROW_GAP/SLOT_ORDER directly. A hand-synced duplicate constant
-- used to live here and drifted out of sync the first time BiSWindow.lua's ROW_H changed (a
-- clipped bottom row / missing bottom border, confirmed live) — computing it removes that whole
-- class of bug instead of just re-guessing a bigger magic number.
local function BisContentH()
    return RS:GetBisContentHeight()
end

-- A stat sitting slightly over target isn't a problem the way being under is, so it gets a
-- calm neutral color instead of an alarming one — only "under" reads as urgent (red).
local COLOR = {
    under  = { 0.92, 0.35, 0.35 },
    on     = { 0.32, 0.85, 0.48 },
    over   = { 0.55, 0.66, 0.85 },
    secret = { 0.62, 0.62, 0.66 },
}
local STATUS_LABEL = {
    under  = L.STATUS_UNDER,
    on     = L.STATUS_ON,
    over   = L.STATUS_OVER,
    -- Core.lua sets this when Blizzard's Secret Values system blocks comparing this stat to its
    -- target (happens in instances/combat) — the bar and % still render, just without a verdict.
    secret = L.STATUS_SECRET,
}
-- Colorblind mode (RS:GetColorblindMode(), Core.lua) variant — a shape glyph prefix so the state
-- doesn't rely on the COLOR table above alone. No new frame elements needed: Render() below just
-- picks this table instead of STATUS_LABEL, so it flows through row.status/row.combined exactly
-- like the plain-English labels do.
local STATUS_LABEL_CB = {
    under  = L.STATUS_UNDER_CB,
    on     = L.STATUS_ON_CB,
    over   = L.STATUS_OVER_CB,
    secret = L.STATUS_SECRET_CB,
}
local function StatusLabels()
    return RS:GetColorblindMode() and STATUS_LABEL_CB or STATUS_LABEL
end

local STAT_LABEL = {
    haste = L.STAT_HASTE, crit = L.STAT_CRIT, mastery = L.STAT_MASTERY, versatility = L.STAT_VERSATILITY,
}
local SHORT_STAT_LABEL = {
    haste = L.STAT_HASTE_SHORT, crit = L.STAT_CRIT_SHORT, mastery = L.STAT_MASTERY_SHORT, versatility = L.STAT_VERSATILITY_SHORT,
}
-- Order the priority line's underlying weights are read in — RecommendedStatsData_StatWeights[key]
-- (RecommendedStatsNode/src/bloodmallet.js) is a flat {haste,crit,mastery,versatility} table with
-- no inherent order, sorted descending by weight at render time (see Render()'s priorityText block).
local PRIORITY_STATS = { "haste", "crit", "mastery", "versatility" }

local CONTENTS = {
    { text = L.CONTENT_RAID,       value = "RAID" },
    { text = L.CONTENT_MYTHICPLUS, value = "MYTHICPLUS" },
}

-- Bar shows target at a fixed position shy of the right edge (not the far end) so "over"
-- readings have room to visibly extend past the tick instead of clipping at the bar's edge.
local TARGET_HEADROOM = 1.15
local TICK_FRAC = 1 / TARGET_HEADROOM

--------------------------------------------------------------------------------
-- Backdrop helper (works with or without BackdropTemplate available)
--------------------------------------------------------------------------------
local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function StyleBackdrop(frame, r, g, b, a, er, eg, eb, ea)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    -- A fresh table every call, not the shared BACKDROP local: Blizzard's SetBackdrop skips
    -- recomputing border geometry when handed the same backdropInfo table reference as last
    -- time. Panel starts at the taller BiS-tab height, then SyncTabUI immediately shrinks it to
    -- the Stats-tab height on first show (default active tab) and reapplies this same BACKDROP
    -- table — which used to be a silent no-op, leaving the border geometry stuck at the tall
    -- size and the bottom edge never redrawn for the shorter one.
    frame:SetBackdrop({
        bgFile   = BACKDROP.bgFile,
        edgeFile = BACKDROP.edgeFile,
        edgeSize = BACKDROP.edgeSize,
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(er or 0, eg or 0, eb or 0, ea or 0.55)
end

--------------------------------------------------------------------------------
-- Skins — the tick and border each had their own neutral default before skins existed
-- (white tick, grey border), distinct from the tab text's original gold, so "Default"
-- must keep reproducing those exact colors rather than picking up RS:GetAccentColor()'s
-- gold fallback. Only Class/Custom skins substitute the resolved accent.
--------------------------------------------------------------------------------
local DEFAULT_TICK_COLOR   = { 1, 1, 1 }
local DEFAULT_BORDER_COLOR = { 0.25, 0.27, 0.33 }

local function TickColor()
    if RS:GetSkin() == "DEFAULT" then return DEFAULT_TICK_COLOR end
    return RS:GetAccentColor()
end
local function BorderColor()
    if RS:GetSkin() == "DEFAULT" then return DEFAULT_BORDER_COLOR end
    return RS:GetAccentColor()
end

--------------------------------------------------------------------------------
-- Tab buttons — flat colored rectangles (matching this addon's borderless look
-- elsewhere) rather than Blizzard's stock tab chrome, which is styled for sitting
-- on CharacterFrame's own edge, not a floating window.
--------------------------------------------------------------------------------
local TAB_ACTIVE_BG    = { 0.16, 0.17, 0.22, 1 }
local TAB_INACTIVE_BG  = { 0.043, 0.047, 0.063, 1 }
local TAB_INACTIVE_TEXT = { 0.62, 0.62, 0.66 }

local function CreateTabButton(parent, label, tabValue)
    local btn = CreateFrame("Button", nil, parent)
    btn.tabValue = tabValue

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(unpack(TAB_INACTIVE_BG))

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(label)
    btn.label:SetTextColor(unpack(TAB_INACTIVE_TEXT))

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)
    btn:SetHighlightTexture(highlight)

    btn:SetScript("OnClick", function(self) RS:SetActiveTab(self.tabValue) end)
    return btn
end

-- Active tab text uses the current skin accent (RS:GetAccentColor(), Core.lua) rather than a
-- fixed color, so a skin change just needs SyncTabUI() re-run to pick it up (see the
-- RS.skinListeners registration at the bottom of this file) — no separate re-render path.
local function ApplyTabVisual(btn, isActive)
    btn.bg:SetColorTexture(unpack(isActive and TAB_ACTIVE_BG or TAB_INACTIVE_BG))
    local textColor = isActive and RS:GetAccentColor() or TAB_INACTIVE_TEXT
    btn.label:SetTextColor(textColor[1], textColor[2], textColor[3])
end

--------------------------------------------------------------------------------
-- Build one stat row (flat — no per-row box, just generous spacing between rows)
--------------------------------------------------------------------------------
-- Reads the font PATH off GameFontNormal rather than hardcoding "Fonts\FRIZQT__.ttf" — that's
-- the Latin-only default font, so hardcoding it broke CJK stat names (row.name, e.g. "加速")
-- under a zhTW/zhCN client: Blizzard swaps GameFontNormal's underlying font to a CJK-capable one
-- per locale (that's how its own default UI renders correctly in every locale it ships), but a
-- literal path bypasses that entirely and always gets the Latin-only file regardless of locale.
local function SetFont(fontString, size, flags)
    local fontPath = select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.ttf"
    fontString:SetFont(fontPath, size, flags or "")
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_W, ROW_H_BY_SIZE.DEFAULT)

    -- stat name (top-left, prominent)
    row.name = row:CreateFontString(nil, "OVERLAY")
    SetFont(row.name, 15, "OUTLINE")
    row.name:SetPoint("TOPLEFT", 0, 0)
    row.name:SetTextColor(1, 1, 1)

    -- status (top-right, colored, small)
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("TOPRIGHT", 0, -2)

    -- current value (big, bold)
    row.current = row:CreateFontString(nil, "OVERLAY")
    SetFont(row.current, 22, "OUTLINE")
    row.current:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.current:SetTextColor(1, 1, 1)

    -- "target X%" (dim, inline after the current value)
    row.target = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.target:SetPoint("LEFT", row.current, "RIGHT", 8, -1)

    -- progress track + fill — anchored right below the current-value text (not pinned to this
    -- row's bottom edge) so the gap is exactly BAR_GAP regardless of font metrics, instead of
    -- whatever's left over between the text and a fixed row height.
    row.barBG = row:CreateTexture(nil, "ARTWORK")
    row.barBG:SetSize(ROW_W, BAR_H)
    row.barBG:SetPoint("TOPLEFT", row.current, "BOTTOMLEFT", 0, -BAR_GAP)
    row.barBG:SetColorTexture(1, 1, 1, 0.08)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row.barBG)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    row.bar:SetMinMaxValues(0, 1)

    -- target tick — positioned here at the TICK_FRAC fallback spot (matches what Render() computes
    -- whenever a key has no "high" reading yet, see stat.high handling there) purely so it isn't
    -- sitting at 0,0 for the one frame before the first Render call. Every real render repositions
    -- it based on that key's actual target/barMax ratio, which varies once a "high" reading is
    -- present (see barMax below) — it's no longer a fixed fraction across every row. Colored via
    -- TickColor() (white under the Default skin, matching this addon's original look, or the skin
    -- accent under Class/Custom); re-tinted in place on a skin change by the RS.skinListeners
    -- registration at the bottom of this file.
    local tickColor = TickColor()
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetSize(2, BAR_H + 6)
    row.tick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], 0.9)
    row.tick:SetPoint("CENTER", row.barBG, "LEFT", ROW_W * TICK_FRAC, 0)

    -- "high" tick — the 90th-percentile reading among top players (RecommendedStatsNode's
    -- aggregate.js, stat.high in Core.lua), marking the far edge of what's actually a "safe" zone
    -- past the median target rather than the bar simply reading full the moment you clear it. Same
    -- color as the target tick but dimmer, so the two read as "primary target" vs. "still normal
    -- past here" rather than two equally-weighted lines. Hidden by default/whenever a key has no
    -- resolved high reading (Render() below only shows it when stat.high is present and above
    -- target) — never guessed or defaulted to the target position.
    row.highTick = row:CreateTexture(nil, "OVERLAY")
    row.highTick:SetSize(2, BAR_H + 6)
    row.highTick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], 0.45)
    row.highTick:Hide()

    -- SMALL/MEDIUM's single-line readout ("Haste  36.3% \194\183 target 30% \194\183 On target") —
    -- built and populated unconditionally in Render() below regardless of which size is active;
    -- ApplyRowSize (below) is solely what shows/hides/positions it, so Render() never needs to
    -- know or branch on the current size.
    row.combined = row:CreateFontString(nil, "OVERLAY")
    SetFont(row.combined, 13, "")
    row.combined:SetJustifyH("LEFT")
    row.combined:SetTextColor(1, 1, 1)
    row.combined:Hide()

    -- LARGE's extra "+X.X% from target" line under the bar.
    row.delta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.delta:SetJustifyH("LEFT")
    row.delta:Hide()

    return row
end

-- Shows/hides/positions each row's elements for the given size — pure layout, no data. Content
-- is always filled in by Render() regardless of which elements are currently shown, so a size
-- change never needs to re-fetch RS:Evaluate() to look right.
local function ApplyRowSize(row, size)
    row.name:ClearAllPoints()
    row.status:ClearAllPoints()
    row.current:ClearAllPoints()
    row.target:ClearAllPoints()
    row.barBG:ClearAllPoints()
    row.combined:ClearAllPoints()
    row.delta:ClearAllPoints()

    if size == "SMALL" or size == "MEDIUM" then
        row.name:Hide(); row.current:Hide(); row.target:Hide(); row.status:Hide(); row.delta:Hide()
        row.combined:Show()
        row.combined:SetWidth(ROW_W)
        row.combined:SetPoint("TOPLEFT", 0, 0)

        if size == "SMALL" then
            row.barBG:Hide(); row.bar:Hide(); row.tick:Hide(); row.highTick:Hide()
        else -- MEDIUM
            row.barBG:Show(); row.bar:Show(); row.tick:Show()
            -- row.highTick is left alone here — Render() is the sole authority on whether it's
            -- actually shown (only when stat.high is present), not this pure-layout function.
            row.barBG:SetPoint("TOPLEFT", row.combined, "BOTTOMLEFT", 0, -BAR_GAP)
        end
    else -- DEFAULT / LARGE
        row.combined:Hide()
        row.name:Show(); row.current:Show(); row.target:Show(); row.status:Show()
        row.barBG:Show(); row.bar:Show(); row.tick:Show()
        -- row.highTick: see the MEDIUM branch's comment above — Render() decides its visibility.

        row.name:SetPoint("TOPLEFT", 0, 0)
        row.status:SetPoint("TOPRIGHT", 0, -2)
        row.current:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.target:SetPoint("LEFT", row.current, "RIGHT", 8, -1)
        row.barBG:SetPoint("TOPLEFT", row.current, "BOTTOMLEFT", 0, -BAR_GAP)

        if size == "LARGE" then
            row.delta:Show()
            row.delta:SetPoint("TOPLEFT", row.barBG, "BOTTOMLEFT", 0, -4)
        else
            row.delta:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Panel + dropdown + tabs (created lazily)
--------------------------------------------------------------------------------
local panel, dropdown, sizeDropdown, statsTab, bisTab, statsPage
local rows = {}
local emptyText, footerText, priorityText

local function ContentLabel()
    local cur = RS:GetContent()
    for _, c in ipairs(CONTENTS) do if c.value == cur then return c.text end end
    return L.SELECT
end

local function BuildDropdown()
    dropdown = CreateFrame("DropdownButton", "RecommendedStatsContentDropdown", panel, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(120)
    dropdown:SetPoint("TOPRIGHT", -12, -(8 + TAB_H + 6))
    dropdown:SetDefaultText(ContentLabel())

    dropdown:SetupMenu(function(_, root)
        for _, c in ipairs(CONTENTS) do
            local hasData = RS:HasDataFor(c.value)
            local radio = root:CreateRadio(
                hasData and c.text or (c.text .. " (no data)"),
                function() return RS:GetContent() == c.value end,      -- isSelected
                function()                                             -- onSelect
                    RS:SetContent(c.value)
                    dropdown:SetDefaultText(ContentLabel())
                    return MenuResponse.Refresh
                end
            )
            radio:SetEnabled(hasData)
        end
    end)
end

-- Row-size shortcut (same setting as UI/OptionsPanel.lua's dropdown, RS:GetStatsSize()/
-- RS:SetStatsSize()) — sits left of the Raid/Mythic+ dropdown so it's a one-click change without
-- leaving the panel. Only relevant to the Stats page, so SyncTabUI hides it while BiS Gear is
-- active (see below); ApplyStatsSizeToPanel keeps its label in sync when changed from Options.
local SIZES = {
    { text = L.SIZE_DEFAULT, value = "DEFAULT" },
    { text = L.SIZE_SMALL,   value = "SMALL" },
    { text = L.SIZE_MEDIUM,  value = "MEDIUM" },
    { text = L.SIZE_LARGE,   value = "LARGE" },
}

local function SizeLabel()
    local cur = RS:GetStatsSize()
    for _, s in ipairs(SIZES) do if s.value == cur then return s.text end end
    return L.SELECT
end

local function BuildSizeDropdown()
    sizeDropdown = CreateFrame("DropdownButton", "RecommendedStatsPanelSizeDropdown", panel, "WowStyle1DropdownTemplate")
    sizeDropdown:SetWidth(90)
    sizeDropdown:SetPoint("RIGHT", dropdown, "LEFT", -8, 0)
    sizeDropdown:SetDefaultText(SizeLabel())

    sizeDropdown:SetupMenu(function(_, root)
        for _, s in ipairs(SIZES) do
            root:CreateRadio(
                s.text,
                function() return RS:GetStatsSize() == s.value end,
                function()
                    RS:SetStatsSize(s.value)
                    sizeDropdown:SetDefaultText(SizeLabel())
                    return MenuResponse.Refresh
                end
            )
        end
    end)
end

local STALE_COLOR = { 0.95, 0.65, 0.3 } -- same amber as BiSWindow.lua's "no Mythic logs yet" hint

-- "X of Y players" when Data/SampleSize.lua has this key (RS:GetSampleSizeFor) — the real count
-- this key's targets came from, which can be well under the configured target early in a tier —
-- falling back to the old "top Y" wording only when that per-key data isn't available at all.
local function FooterLine(key)
    local m = RecommendedStatsData_Meta
    if not m then return "" end
    local n = RS:GetSampleSizeFor(key)
    local sampleText = n and L.FOOTER_SAMPLE_OF_TARGET:format(n, m.sampleSize or 0) or L.FOOTER_TOP_N:format(m.sampleSize or 0)
    local line = L.FOOTER_LINE:format(sampleText, m.gamePatch or "?", m.updated or "?")
    if RS:IsDataStale() then line = line .. L.FOOTER_MAYBE_STALE end
    return line
end

local function ApplyFooterColor(key)
    if RS:IsDataStale() or RS:IsSampleSizeLow(key) then
        footerText:SetTextColor(unpack(STALE_COLOR))
    else
        footerText:SetTextColor(0.5, 0.5, 0.5) -- GameFontDisableSmall's default gray
    end
end

-- Re-strides/resizes the 4 stat rows and statsPage for the current RS:GetStatsSize() — called
-- once at panel creation and again from RS.statsSizeListeners whenever the option changes.
local function LayoutRows()
    local size = RS:GetStatsSize()
    local rowH = CurrentRowH()
    for i, row in ipairs(rows) do
        row:SetSize(ROW_W, rowH)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, -(i - 1) * (rowH + ROW_GAP))
        ApplyRowSize(row, size)
    end
    if statsPage then statsPage:SetHeight(StatsContentH()) end
end

local function EnsurePanel()
    if panel then return end

    -- Parented to UIParent (not CharacterFrame) so the panel's own layout doesn't get
    -- dragged around by whatever CharacterFrame reskins/resizes are doing underneath
    -- (Chonky Character Sheet, MyCharacterSheet, etc.) — it just docks beside it by
    -- default and can be dragged anywhere, remembering the position in the DB.
    panel = CreateFrame("Frame", "RecommendedStatsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + math.max(StatsContentH(), BisContentH()) + 10)
    local border = BorderColor()
    StyleBackdrop(panel, 0.043, 0.047, 0.063, 0.97, border[1], border[2], border[3], 0.7)

    RS:MakeMovable(panel, "panelPos", function()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 6, -4)
    end)

    -- Escape closes this panel like any other UI window. When ATTACHED this is
    -- redundant with CharacterFrame's own Escape-close (which already cascades
    -- through the OnHide hook below), so only persist the closed state — and
    -- thus only skip the auto-reopen on next login's SyncVisibility — while FREE.
    tinsert(UISpecialFrames, "RecommendedStatsPanel")
    panel:SetScript("OnHide", function()
        if RS:GetAttachMode() == "FREE" then
            RS:SetPanelsShown(false)
        end
    end)

    -- Tabs replace the old static title — each label doubles as the section name.
    statsTab = CreateTabButton(panel, L.TAB_STATS, "STATS")
    local tabW = (PANEL_W - 24 - TAB_GAP) / 2
    statsTab:SetSize(tabW, TAB_H)
    statsTab:SetPoint("TOPLEFT", 12, -8)

    bisTab = CreateTabButton(panel, L.TAB_BIS, "BIS")
    bisTab:SetSize(tabW, TAB_H)
    bisTab:SetPoint("TOPLEFT", statsTab, "TOPRIGHT", TAB_GAP, 0)

    BuildDropdown()
    BuildSizeDropdown()

    -- "Recommended Stats" page: 4 stat rows + footer, all parented here so the whole
    -- section shows/hides as one unit when the tab switches (see SyncTabUI below).
    statsPage = CreateFrame("Frame", nil, panel)
    statsPage:SetPoint("TOPLEFT", 0, -HEADER_H)
    statsPage:SetPoint("TOPRIGHT", 0, -HEADER_H)
    statsPage:SetHeight(StatsContentH())

    for i = 1, 4 do
        rows[i] = CreateRow(statsPage)
    end
    LayoutRows()

    emptyText = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -20)
    emptyText:SetWidth(PANEL_W - 30)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()

    footerText = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMLEFT", statsPage, "BOTTOMLEFT", 12, 0)
    footerText:SetText(FooterLine())

    -- Stat-priority line (RecommendedStatsData_StatWeights, from bloodmallet — see Render()) sits
    -- just above the footer; hidden by default since most keys won't have this data until a
    -- rebuild resolves it (or ever, for a spec/patch bloodmallet doesn't cover).
    priorityText = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    priorityText:SetPoint("BOTTOMLEFT", footerText, "TOPLEFT", 0, 4)
    priorityText:Hide()

    -- "BiS Gear" page: an empty container UI/BiSWindow.lua populates with its own rows the
    -- first time this merged window is created (see that file's SyncVisibility/EnsureContent).
    local bisPage = CreateFrame("Frame", nil, panel)
    bisPage:SetPoint("TOPLEFT", 0, -HEADER_H)
    bisPage:SetPoint("TOPRIGHT", 0, -HEADER_H)
    bisPage:SetHeight(BisContentH())
    RS.bisPage = bisPage
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------
local function ShowEmpty(msg)
    for _, row in ipairs(rows) do row:Hide() end
    if footerText then footerText:Hide() end
    if priorityText then priorityText:Hide() end
    emptyText:SetText(msg)
    emptyText:Show()
end

local function ColorHex(col)
    return ("|cff%02x%02x%02x"):format(
        math.floor(col[1] * 255 + 0.5), math.floor(col[2] * 255 + 0.5), math.floor(col[3] * 255 + 0.5)
    )
end

local function Render(data, key)
    -- Recomputed stats (e.g. on login, gear change) must not force the panel into
    -- existence — only RS:SyncVisibility() (character frame open, minimap toggle,
    -- or restoring a standalone session) creates/shows it.
    if not panel then return end
    if dropdown then dropdown:SetDefaultText(ContentLabel()) end

    if not data then
        if key == "schema" then
            ShowEmpty(L.SCHEMA_OUT_OF_DATE)
        else
            ShowEmpty(L.NO_TARGETS_YET)
        end
        return
    end

    emptyText:Hide()
    footerText:Show()
    footerText:SetText(FooterLine(key))
    ApplyFooterColor(key)

    -- Additive alongside the % targets above, not a replacement — see RecommendedStatsNode/
    -- src/bloodmallet.js's own header comment for why this is a rank ORDER, not a true per-player
    -- marginal value. Hidden whenever this key has no resolved weights (bloodmallet fetch failed/
    -- skipped for this spec, or hasn't run yet) rather than showing a misleading default order.
    local weights = RecommendedStatsData_StatWeights and RecommendedStatsData_StatWeights[key]
    if weights then
        local order = {}
        for _, name in ipairs(PRIORITY_STATS) do order[#order + 1] = { name = name, w = weights[name] or 0 } end
        table.sort(order, function(a, b) return a.w > b.w end)
        local labels = {}
        for _, o in ipairs(order) do labels[#labels + 1] = SHORT_STAT_LABEL[o.name] or o.name end
        priorityText:SetText(L.PRIORITY_LINE:format(table.concat(labels, " > ")))
        priorityText:Show()
    else
        priorityText:Hide()
    end

    local statusLabel = StatusLabels()
    for i, row in ipairs(rows) do
        local stat = data[i]
        if not stat then row:Hide()
        else
            row:Show()
            local col = COLOR[stat.state]

            row.name:SetText(STAT_LABEL[stat.name] or stat.name)
            -- SetFormattedText is a sanctioned direct sink for secret values (unlike ("%s"):format
            -- or string.format called ourselves, which are arithmetic-adjacent and would taint-error
            -- exactly like the delta calc in Core.lua) — safe here whether stat.current is secret or not.
            -- stat.rating (Core.lua's ReadRatings) is the raw combat rating alongside the percent —
            -- gear/enchants/gems are itemized in rating (see BiSWindow.lua's own readouts), so this
            -- shows both rather than percent alone. Omitted only if GetCombatRating itself came back
            -- nil, not expected in practice at the levels this addon targets.
            if stat.rating then
                row.current:SetFormattedText(L.CURRENT_VALUE_WITH_RATING, stat.rating, stat.current)
            else
                row.current:SetFormattedText(L.CURRENT_VALUE, stat.current)
            end
            row.current:SetTextColor(col[1], col[2], col[3])
            -- stat.targetRating (Core.lua) is an ESTIMATE (target % converted via the player's own
            -- current rating/percent ratio), unlike stat.rating above which is exact — nil whenever
            -- that ratio wasn't available (secret state, or 0% current), falls back to percent-only.
            -- stat.high (Core.lua) is the 90th-percentile reading among top players, alongside the
            -- median target — nil for data built before this field existed, so this falls back to
            -- the plain target-only strings above rather than ever showing a blank "top" reading.
            if stat.targetRating and stat.high then
                row.target:SetText(L.TARGET_WITH_RATING_AND_HIGH:format(stat.targetRating, stat.target, stat.high))
            elseif stat.targetRating then
                row.target:SetText(L.TARGET_WITH_RATING:format(stat.targetRating, stat.target))
            elseif stat.high then
                row.target:SetText(L.TARGET_WITH_HIGH:format(stat.target, stat.high))
            else
                row.target:SetText(L.TARGET_INLINE:format(stat.target))
            end

            row.status:SetText(statusLabel[stat.state])
            row.status:SetTextColor(col[1], col[2], col[3])

            -- SetMinMaxValues + SetValue let the StatusBar do its own clamping/fill math natively
            -- (also a sanctioned secret sink) instead of us dividing stat.current ourselves.
            -- barMax scales off whichever of target/high is larger, so the bar doesn't just read
            -- "full" the instant you clear the median target — a stat.high reading (present once a
            -- key has one; see Core.lua) pushes the ceiling out past it, leaving room to show BOTH
            -- ticks and a visible "safe" gap between them, matching how it already reads when
            -- stat.high isn't available (that fallback is exactly the old target*TARGET_HEADROOM
            -- behavior, not a separate code path).
            local hasHigh = stat.high and stat.high > stat.target
            local ceiling = hasHigh and stat.high or stat.target
            local barMax = math.max(ceiling * TARGET_HEADROOM, 0.01)
            row.bar:SetMinMaxValues(0, barMax)
            row.bar:SetValue(stat.current)
            -- Both ticks are repositioned every render (not just once at row creation) since their
            -- fraction of barMax now varies per key once stat.high is in play, rather than staying
            -- pinned at the fixed TICK_FRAC every row used to share.
            row.tick:SetPoint("CENTER", row.barBG, "LEFT", ROW_W * (stat.target / barMax), 0)
            if hasHigh then
                row.highTick:SetPoint("CENTER", row.barBG, "LEFT", ROW_W * (stat.high / barMax), 0)
                row.highTick:Show()
            else
                row.highTick:Hide()
            end
            row.bar:SetStatusBarColor(col[1], col[2], col[3])

            -- SMALL/MEDIUM's single-line readout — always filled in regardless of which size is
            -- active (ApplyRowSize is what decides whether it's actually shown), same sanctioned
            -- SetFormattedText sink as row.current above since stat.current may be secret. Same
            -- rating-alongside-percent treatment as row.current above.
            if stat.rating and stat.targetRating then
                row.combined:SetFormattedText(
                    "%s   %d (%.1f%%)  \194\183  target %.0f (%.0f%%)  \194\183  " .. ColorHex(col) .. "%s|r",
                    STAT_LABEL[stat.name] or stat.name, stat.rating, stat.current, stat.targetRating, stat.target, statusLabel[stat.state]
                )
            elseif stat.rating then
                row.combined:SetFormattedText(
                    "%s   %d (%.1f%%)  \194\183  target %.0f%%  \194\183  " .. ColorHex(col) .. "%s|r",
                    STAT_LABEL[stat.name] or stat.name, stat.rating, stat.current, stat.target, statusLabel[stat.state]
                )
            else
                row.combined:SetFormattedText(
                    "%s   %.1f%%  \194\183  target %.0f%%  \194\183  " .. ColorHex(col) .. "%s|r",
                    STAT_LABEL[stat.name] or stat.name, stat.current, stat.target, statusLabel[stat.state]
                )
            end

            -- LARGE's delta line. stat.delta is only nil for state == "secret" (Core.lua never
            -- computes a delta it can't subtract) — a plain already-resolved number otherwise, so
            -- no secret-sink concerns here, unlike stat.current above. stat.deltaRating is the same
            -- estimate as stat.targetRating above, nil under the same conditions.
            if stat.deltaRating then
                row.delta:SetFormattedText(L.DELTA_FROM_TARGET_WITH_RATING, stat.deltaRating, stat.delta)
                row.delta:SetTextColor(col[1], col[2], col[3])
            elseif stat.delta then
                row.delta:SetFormattedText(L.DELTA_FROM_TARGET, stat.delta)
                row.delta:SetTextColor(col[1], col[2], col[3])
            else
                row.delta:SetText("")
            end
        end
    end
end

table.insert(RS.listeners, Render)

--------------------------------------------------------------------------------
-- Visibility: attach mode + minimap toggle drive this, not the character frame
-- directly (see RS:ShouldShowPanels() in Core.lua). This is the ONLY frame now —
-- UI/BiSWindow.lua no longer owns a top-level window of its own.
--------------------------------------------------------------------------------
local function SyncVisibility()
    if RS:ShouldShowPanels() and (RS:GetShowStats() or RS:GetShowBiS()) then
        EnsurePanel()
        RS:RedockIfDefault("panelPos") -- follow CharacterFrame if it moved, unless the user dragged us elsewhere
        panel:Show()
        -- Not RS:Refresh() here — RS:SyncVisibility() (Core.lua) already calls it once, after
        -- every visibilitySyncer (including BiSWindow.lua's lazy content-builder) has run.
    elseif panel then
        panel:Hide()
    end
end
table.insert(RS.visibilitySyncers, SyncVisibility)

-- Which page is visible + the tab buttons' own active/inactive look — RS:SyncVisibility()
-- (Core.lua) calls RS:SyncTabs() right after every visibilitySyncer above has run, so this is
-- guaranteed to see an up-to-date RS.bisPage/statsPage every time.
local function SyncTabUI()
    if not panel then return end
    local active = RS:GetActiveTab()
    statsTab:SetShown(RS:GetShowStats())
    bisTab:SetShown(RS:GetShowBiS())
    ApplyTabVisual(statsTab, active == "STATS")
    ApplyTabVisual(bisTab, active == "BIS")
    statsPage:SetShown(active == "STATS" and RS:GetShowStats())
    if sizeDropdown then sizeDropdown:SetShown(active == "STATS" and RS:GetShowStats()) end
    -- The window used to always stand as tall as the taller of the two tabs (BiS Gear's 16
    -- rows), which left a dead gap below the Stats tab's shorter content whenever it was the
    -- active one — resize to whichever tab is actually showing instead. Top-left stays anchored
    -- (RS:MakeMovable), so this only ever moves the bottom edge.
    panel:SetHeight(HEADER_H + (active == "BIS" and BisContentH() or StatsContentH()) + 10)
    -- Re-applying the backdrop after every resize, not just at creation: a plain SetHeight() on
    -- this frame leaves the border geometry stale unless StyleBackdrop is called again with a
    -- fresh backdrop table (see its own comment — SetBackdrop no-ops on a repeated table
    -- reference), which is what actually redraws the bottom edge at the new size.
    local border = BorderColor()
    StyleBackdrop(panel, 0.043, 0.047, 0.063, 0.97, border[1], border[2], border[3], 0.7)
end
table.insert(RS.tabSyncers, SyncTabUI)

-- Re-strides the rows and resizes the panel when RS:SetStatsSize() changes — fires whether the
-- change came from this panel's own sizeDropdown or UI/OptionsPanel.lua's, so both stay in sync.
-- If the panel hasn't been created yet, EnsurePanel's own LayoutRows() call will already pick up
-- whatever size is current at build time, so there's nothing to redo here.
local function ApplyStatsSizeToPanel()
    if not panel then return end
    LayoutRows()
    SyncTabUI() -- resizes the panel to the new StatsContentH() and redraws the border at that size
    if sizeDropdown then sizeDropdown:SetDefaultText(SizeLabel()) end
end
table.insert(RS.statsSizeListeners, ApplyStatsSizeToPanel)

-- Re-tints already-built chrome in place when the skin setting changes (UI/OptionsPanel.lua).
-- If the panel hasn't been created yet, there's nothing to re-tint — EnsurePanel/CreateRow
-- above already read TickColor()/BorderColor() fresh at build time, so a skin picked before
-- the panel first opens is already correct without this running.
local function ApplySkinToPanel()
    if not panel then return end
    local border = BorderColor()
    panel:SetBackdropBorderColor(border[1], border[2], border[3], 0.7)
    local tick = TickColor()
    for _, row in ipairs(rows) do
        row.tick:SetColorTexture(tick[1], tick[2], tick[3], 0.9)
        row.highTick:SetColorTexture(tick[1], tick[2], tick[3], 0.45)
    end
    SyncTabUI() -- re-picks the active tab's text color via ApplyTabVisual -> RS:GetAccentColor()
end
table.insert(RS.skinListeners, ApplySkinToPanel)

-- Routed through the centralized dispatcher (rather than calling the local SyncVisibility
-- above directly) so CharacterFrame's own show/hide also runs every other registered
-- visibilitySyncer (UI/BiSWindow.lua's lazy content-builder) and RS:SyncTabs() in one pass.
CharacterFrame:HookScript("OnShow", function() RS:SyncVisibility() end)
CharacterFrame:HookScript("OnHide", function() RS:SyncVisibility() end)
