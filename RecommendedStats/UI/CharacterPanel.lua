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

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W   = 360 -- shared with BiS Gear's row width requirements (see UI/BiSWindow.lua)
local ROW_W     = PANEL_W - 24  -- content width inside the panel's side padding
-- The bar is anchored directly below the current-value text (see CreateRow's BAR_GAP), not
-- pinned to this row height's bottom edge, so ROW_H only needs to be "tall enough to hold name +
-- current-value + BAR_GAP + bar + a little breathing room" — it's the row-to-row stride, not a
-- box the content is stretched to fill.
local ROW_H     = 66
local ROW_GAP   = 8
local FOOTER_H  = 20
local BAR_H     = 8
local BAR_GAP   = 6 -- vertical gap between the current-value text and the bar below it

-- Shared header: 8px top pad + tab row + gap + dropdown row + 8px bottom pad. Both pages
-- (statsPage here, RS.bisPage from BiSWindow.lua) anchor their own top-left below this.
local TAB_H          = 24
local TAB_GAP        = 4
local DROPDOWN_ROW_H = 20
local HEADER_H       = 8 + TAB_H + 6 + DROPDOWN_ROW_H + 8

local STATS_CONTENT_H = (ROW_H + ROW_GAP) * 4 + FOOTER_H + 6
-- Matches UI/BiSWindow.lua's own row math (16 rows + its small sub-header) — kept in sync by
-- hand since each UI file already owns its own layout constants independently in this addon;
-- a little slack is fine since bisPage is just a plain container.
local BIS_CONTENT_H = 430

-- A stat sitting slightly over target isn't a problem the way being under is, so it gets a
-- calm neutral color instead of an alarming one — only "under" reads as urgent (red).
local COLOR = {
    under  = { 0.92, 0.35, 0.35 },
    on     = { 0.32, 0.85, 0.48 },
    over   = { 0.55, 0.66, 0.85 },
    secret = { 0.62, 0.62, 0.66 },
}
local STATUS_LABEL = {
    under  = "Too low",
    on     = "On target",
    over   = "Over \194\183 fine",
    -- Core.lua sets this when Blizzard's Secret Values system blocks comparing this stat to its
    -- target (happens in instances/combat) — the bar and % still render, just without a verdict.
    secret = "Can't compare here",
}

local STAT_LABEL = {
    haste = "Haste", crit = "Critical Strike", mastery = "Mastery", versatility = "Versatility",
}

local CONTENTS = {
    { text = "Raid",     value = "RAID" },
    { text = "Mythic+",  value = "MYTHICPLUS" },
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
    frame:SetBackdrop(BACKDROP)
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
local function SetFont(fontString, size, flags)
    fontString:SetFont("Fonts\\FRIZQT__.ttf", size, flags or "")
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_W, ROW_H)

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

    -- target tick — always at the same relative position (TICK_FRAC never changes), so it's
    -- placed once here rather than recalculated on every render. Colored via TickColor() (white
    -- under the Default skin, matching this addon's original look, or the skin accent under
    -- Class/Custom); re-tinted in place on a skin change by the RS.skinListeners registration
    -- at the bottom of this file.
    local tickColor = TickColor()
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetSize(2, BAR_H + 6)
    row.tick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], 0.9)
    row.tick:SetPoint("CENTER", row.barBG, "LEFT", ROW_W * TICK_FRAC, 0)

    return row
end

--------------------------------------------------------------------------------
-- Panel + dropdown + tabs (created lazily)
--------------------------------------------------------------------------------
local panel, dropdown, statsTab, bisTab, statsPage
local rows = {}
local emptyText, footerText

local function ContentLabel()
    local cur = RS:GetContent()
    for _, c in ipairs(CONTENTS) do if c.value == cur then return c.text end end
    return "Select"
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

local STALE_COLOR = { 0.95, 0.65, 0.3 } -- same amber as BiSWindow.lua's "no Mythic logs yet" hint

-- "X of Y players" when Data/SampleSize.lua has this key (RS:GetSampleSizeFor) — the real count
-- this key's targets came from, which can be well under the configured target early in a tier —
-- falling back to the old "top Y" wording only when that per-key data isn't available at all.
local function FooterLine(key)
    local m = RecommendedStatsData_Meta
    if not m then return "" end
    local n = RS:GetSampleSizeFor(key)
    local sampleText = n and ("%d of %d players"):format(n, m.sampleSize or 0) or ("top %d players"):format(m.sampleSize or 0)
    local line = ("Targets: %s \194\183 %s \194\183 updated %s"):format(sampleText, m.gamePatch or "?", m.updated or "?")
    if RS:IsDataStale() then line = line .. " (may be stale)" end
    return line
end

local function ApplyFooterColor(key)
    if RS:IsDataStale() or RS:IsSampleSizeLow(key) then
        footerText:SetTextColor(unpack(STALE_COLOR))
    else
        footerText:SetTextColor(0.5, 0.5, 0.5) -- GameFontDisableSmall's default gray
    end
end

local function EnsurePanel()
    if panel then return end

    -- Parented to UIParent (not CharacterFrame) so the panel's own layout doesn't get
    -- dragged around by whatever CharacterFrame reskins/resizes are doing underneath
    -- (Chonky Character Sheet, MyCharacterSheet, etc.) — it just docks beside it by
    -- default and can be dragged anywhere, remembering the position in the DB.
    panel = CreateFrame("Frame", "RecommendedStatsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + math.max(STATS_CONTENT_H, BIS_CONTENT_H) + 10)
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
    statsTab = CreateTabButton(panel, "Recommended Stats", "STATS")
    local tabW = (PANEL_W - 24 - TAB_GAP) / 2
    statsTab:SetSize(tabW, TAB_H)
    statsTab:SetPoint("TOPLEFT", 12, -8)

    bisTab = CreateTabButton(panel, "BiS Gear", "BIS")
    bisTab:SetSize(tabW, TAB_H)
    bisTab:SetPoint("TOPLEFT", statsTab, "TOPRIGHT", TAB_GAP, 0)

    BuildDropdown()

    -- "Recommended Stats" page: 4 stat rows + footer, all parented here so the whole
    -- section shows/hides as one unit when the tab switches (see SyncTabUI below).
    statsPage = CreateFrame("Frame", nil, panel)
    statsPage:SetPoint("TOPLEFT", 0, -HEADER_H)
    statsPage:SetPoint("TOPRIGHT", 0, -HEADER_H)
    statsPage:SetHeight(STATS_CONTENT_H)

    local top = 0
    for i = 1, 4 do
        local row = CreateRow(statsPage)
        row:SetPoint("TOPLEFT", 12, top - (i - 1) * (ROW_H + ROW_GAP))
        rows[i] = row
    end

    emptyText = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -20)
    emptyText:SetWidth(PANEL_W - 30)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()

    footerText = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMLEFT", statsPage, "BOTTOMLEFT", 12, 0)
    footerText:SetText(FooterLine())

    -- "BiS Gear" page: an empty container UI/BiSWindow.lua populates with its own rows the
    -- first time this merged window is created (see that file's SyncVisibility/EnsureContent).
    local bisPage = CreateFrame("Frame", nil, panel)
    bisPage:SetPoint("TOPLEFT", 0, -HEADER_H)
    bisPage:SetPoint("TOPRIGHT", 0, -HEADER_H)
    bisPage:SetHeight(BIS_CONTENT_H)
    RS.bisPage = bisPage
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------
local function ShowEmpty(msg)
    for _, row in ipairs(rows) do row:Hide() end
    if footerText then footerText:Hide() end
    emptyText:SetText(msg)
    emptyText:Show()
end

local function Render(data, key)
    -- Recomputed stats (e.g. on login, gear change) must not force the panel into
    -- existence — only RS:SyncVisibility() (character frame open, minimap toggle,
    -- or restoring a standalone session) creates/shows it.
    if not panel then return end
    if dropdown then dropdown:SetDefaultText(ContentLabel()) end

    if not data then
        if key == "schema" then
            ShowEmpty("Stat data is out of date for this addon version. Please update.")
        else
            ShowEmpty("No stat targets for your current spec + content yet.")
        end
        return
    end

    emptyText:Hide()
    footerText:Show()
    footerText:SetText(FooterLine(key))
    ApplyFooterColor(key)

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
            row.current:SetFormattedText("%.1f%%", stat.current)
            row.current:SetTextColor(col[1], col[2], col[3])
            row.target:SetText(("target %.0f%%"):format(stat.target)) -- stat.target is always our own data, never secret

            row.status:SetText(STATUS_LABEL[stat.state])
            row.status:SetTextColor(col[1], col[2], col[3])

            -- SetMinMaxValues + SetValue let the StatusBar do its own clamping/fill math natively
            -- (also a sanctioned secret sink) instead of us dividing stat.current ourselves.
            local barMax = math.max(stat.target * TARGET_HEADROOM, 0.01)
            row.bar:SetMinMaxValues(0, barMax)
            row.bar:SetValue(stat.current)
            row.bar:SetStatusBarColor(col[1], col[2], col[3])
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
    -- The window used to always stand as tall as the taller of the two tabs (BiS Gear's 16
    -- rows), which left a dead gap below the Stats tab's shorter content whenever it was the
    -- active one — resize to whichever tab is actually showing instead. Top-left stays anchored
    -- (RS:MakeMovable), so this only ever moves the bottom edge.
    panel:SetHeight(HEADER_H + (active == "BIS" and BIS_CONTENT_H or STATS_CONTENT_H) + 10)
    -- Re-applying the backdrop after every resize, not just at creation: a plain SetHeight() on
    -- this frame was leaving the bottom edge texture stale/undrawn (visible as a missing bottom
    -- border on the shorter Stats tab) — forcing a fresh SetBackdrop pass at the new size is a
    -- known-safe way to clear that regardless of the exact underlying cause.
    local border = BorderColor()
    StyleBackdrop(panel, 0.043, 0.047, 0.063, 0.97, border[1], border[2], border[3], 0.7)
end
table.insert(RS.tabSyncers, SyncTabUI)

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
    end
    SyncTabUI() -- re-picks the active tab's text color via ApplyTabVisual -> RS:GetAccentColor()
end
table.insert(RS.skinListeners, ApplySkinToPanel)

-- Routed through the centralized dispatcher (rather than calling the local SyncVisibility
-- above directly) so CharacterFrame's own show/hide also runs every other registered
-- visibilitySyncer (UI/BiSWindow.lua's lazy content-builder) and RS:SyncTabs() in one pass.
CharacterFrame:HookScript("OnShow", function() RS:SyncVisibility() end)
CharacterFrame:HookScript("OnHide", function() RS:SyncVisibility() end)
