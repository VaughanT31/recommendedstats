-- RecommendedStats :: UI/CharacterPanel.lua
-- Flat, borderless stat readout anchored to the character window, with a Raid / Mythic+
-- dropdown. Each row shows current vs target with a target-tick on the progress bar so
-- "how far off" is visible at a glance, not just "over/under".
--
-- Depends on Core.lua providing:
--   RS:Evaluate()  -> { {name,current,target,delta,state}, ... }, key   (state = "under"|"on"|"over")
--   RS:GetContent() / RS:SetContent(c)                                  (c = "RAID"|"MYTHICPLUS")
--   RS.listeners (table)  and  RS:Refresh()
--   RecommendedStatsData_Meta (sampleSize, gamePatch, updated)
--
-- NOTE: the dropdown uses the modern (11.x+/12.x) menu system
-- (DropdownButton + WowStyle1DropdownTemplate + SetupMenu). Verify the template
-- name resolves in your client; it is the current retail dropdown.

local RS = RecommendedStats

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W   = 300
local ROW_W     = PANEL_W - 24  -- content width inside the panel's side padding
local ROW_H     = 78
local ROW_GAP   = 12
local HEADER_H  = 46
local FOOTER_H  = 20
local BAR_H     = 8

-- A stat sitting slightly over target isn't a problem the way being under is, so it gets a
-- calm neutral color instead of an alarming one — only "under" reads as urgent (red).
local COLOR = {
    under = { 0.92, 0.35, 0.35 },
    on    = { 0.32, 0.85, 0.48 },
    over  = { 0.55, 0.66, 0.85 },
}
local STATUS_LABEL = {
    under = "Too low",
    on    = "On target",
    over  = "Over \194\183 fine",
}

local GOLD = { 1, 0.82, 0.15 }

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
    row.current:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.current:SetTextColor(1, 1, 1)

    -- "target X%" (dim, inline after the current value)
    row.target = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.target:SetPoint("LEFT", row.current, "RIGHT", 8, -1)

    -- progress track + fill
    row.barBG = row:CreateTexture(nil, "ARTWORK")
    row.barBG:SetSize(ROW_W, BAR_H)
    row.barBG:SetPoint("BOTTOMLEFT", 0, 4)
    row.barBG:SetColorTexture(1, 1, 1, 0.08)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row.barBG)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    row.bar:SetMinMaxValues(0, 1)

    -- target tick — always at the same relative position (TICK_FRAC never changes), so it's
    -- placed once here rather than recalculated on every render.
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetSize(2, BAR_H + 6)
    row.tick:SetColorTexture(1, 1, 1, 0.9)
    row.tick:SetPoint("CENTER", row.barBG, "LEFT", ROW_W * TICK_FRAC, 0)

    return row
end

--------------------------------------------------------------------------------
-- Panel + dropdown (created lazily)
--------------------------------------------------------------------------------
local panel, dropdown
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
    dropdown:SetPoint("TOPRIGHT", -8, -8)
    dropdown:SetDefaultText(ContentLabel())

    dropdown:SetupMenu(function(_, root)
        for _, c in ipairs(CONTENTS) do
            root:CreateRadio(
                c.text,
                function() return RS:GetContent() == c.value end,      -- isSelected
                function()                                             -- onSelect
                    RS:SetContent(c.value)
                    dropdown:SetDefaultText(ContentLabel())
                    return MenuResponse.Refresh
                end
            )
        end
    end)
end

local function FooterLine()
    local m = RecommendedStatsData_Meta
    if not m then return "" end
    return ("Targets: top %d \194\183 %s \194\183 updated %s"):format(m.sampleSize or 0, m.gamePatch or "?", m.updated or "?")
end

local function EnsurePanel()
    if panel then return end

    panel = CreateFrame("Frame", "RecommendedStatsPanel", CharacterFrame, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + (ROW_H + ROW_GAP) * 4 + FOOTER_H + 6)
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 6, -4)
    StyleBackdrop(panel, 0.043, 0.047, 0.063, 0.97, 0.25, 0.27, 0.33, 0.7)

    RS.statPanel = panel -- so BiSWindow.lua can dock next to this instead of off-screen to the left

    -- title (shares the header row with the dropdown, so keep it to one line)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("LEFT", panel, "TOPLEFT", 12, -22)
    panel.title:SetWidth(PANEL_W - 12 - 120 - 8 - 8) -- leaves room for the dropdown
    panel.title:SetJustifyH("LEFT")
    panel.title:SetText("Recommended Stats")
    panel.title:SetTextColor(unpack(GOLD))

    BuildDropdown()

    -- stat rows
    local top = -HEADER_H
    for i = 1, 4 do
        local row = CreateRow(panel)
        row:SetPoint("TOPLEFT", 12, top - (i - 1) * (ROW_H + ROW_GAP))
        rows[i] = row
    end

    -- empty / no-data message
    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -HEADER_H - 20)
    emptyText:SetWidth(PANEL_W - 30)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()

    -- footer meta line
    footerText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMLEFT", 12, 8)
    footerText:SetText(FooterLine())
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
    EnsurePanel()
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
    footerText:SetText(FooterLine())

    for i, row in ipairs(rows) do
        local stat = data[i]
        if not stat then row:Hide()
        else
            row:Show()
            local col = COLOR[stat.state]

            row.name:SetText(STAT_LABEL[stat.name] or stat.name)
            row.current:SetText(("%.1f%%"):format(stat.current))
            row.current:SetTextColor(col[1], col[2], col[3])
            row.target:SetText(("target %.0f%%"):format(stat.target))

            row.status:SetText(STATUS_LABEL[stat.state])
            row.status:SetTextColor(col[1], col[2], col[3])

            local barMax = math.max(stat.target * TARGET_HEADROOM, 0.01)
            row.bar:SetValue(math.min(stat.current, barMax) / barMax)
            row.bar:SetStatusBarColor(col[1], col[2], col[3])
        end
    end
end

table.insert(RS.listeners, Render)

--------------------------------------------------------------------------------
-- Show with the character sheet; refresh on open
--------------------------------------------------------------------------------
CharacterFrame:HookScript("OnShow", function()
    EnsurePanel()
    RS:Refresh()
end)
