-- RecommendedStats :: UI/CharacterPanel.lua
-- Drop-in replacement for the earlier stub. Card-style secondary-stat readout
-- anchored to the character window, with a Raid / Mythic+ / PvP dropdown.
--
-- Depends on Core.lua providing:
--   RS:Evaluate()  -> { {name,current,target,delta,state}, ... }, key   (state = "under"|"on"|"over")
--   RS:GetContent() / RS:SetContent(c)                                  (c = "RAID"|"MYTHICPLUS")
--   RS.listeners (table)  and  RS:Refresh()
--
-- NOTE: the dropdown uses the modern (11.x+/12.x) menu system
-- (DropdownButton + WowStyle1DropdownTemplate + SetupMenu). Verify the template
-- name resolves in your client; it is the current retail dropdown.

local RS = RecommendedStats

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W       = 280
local CARD_W        = 256
local CARD_H        = 82
local CARD_GAP      = 8
local HEADER_H      = 44      -- title + dropdown, side by side on one row

local COLOR = {
    under = { 0.85, 0.22, 0.22 },   -- red   : below target (need more)
    on    = { 0.24, 0.80, 0.36 },   -- green : on target
    over  = { 0.92, 0.66, 0.13 },   -- amber : above target (excess)
    dim   = { 0.62, 0.62, 0.66 },
}

local STATUS = {
    under = { text = "Too low", arrow = "|TInterface\\MoneyFrame\\Arrow-Down-Up:12:12|t" },
    on    = { text = "On target", arrow = "" },
    over  = { text = "Excess",  arrow = "|TInterface\\MoneyFrame\\Arrow-Up-Up:12:12|t" },
}

local STAT_LABEL = {
    haste = "Haste", crit = "Critical Strike", mastery = "Mastery", versatility = "Versatility",
}

local CONTENTS = {
    { text = "Raid",     value = "RAID" },
    { text = "Mythic+",  value = "MYTHICPLUS" },
}

--------------------------------------------------------------------------------
-- Backdrop helper (works with or without BackdropTemplate available)
--------------------------------------------------------------------------------
local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function StyleBackdrop(frame, r, g, b, a, er, eg, eb)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(er or 0, eg or 0, eb or 0, 0.55)
end

--------------------------------------------------------------------------------
-- Build one stat card
--------------------------------------------------------------------------------
local function CreateCard(parent, index)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    StyleBackdrop(card, 0.09, 0.09, 0.11, 0.90)

    -- colored accent strip down the left edge
    card.accent = card:CreateTexture(nil, "OVERLAY")
    card.accent:SetPoint("TOPLEFT", 1, -1)
    card.accent:SetPoint("BOTTOMLEFT", 1, 1)
    card.accent:SetWidth(3)
    card.accent:SetColorTexture(1, 1, 1, 1)

    -- stat name (top-left)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", 12, -8)

    -- current value (big, below name)
    card.current = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.current:SetPoint("TOPLEFT", 12, -24)

    -- "target : X%" (dim, to the right of current)
    card.target = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.target:SetPoint("LEFT", card.current, "RIGHT", 6, 0)

    -- progress bar (near the bottom)
    card.bar = CreateFrame("StatusBar", nil, card)
    card.bar:SetPoint("BOTTOMLEFT", 12, 8)
    card.bar:SetPoint("BOTTOMRIGHT", -12, 8)
    card.bar:SetHeight(6)
    card.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.bar:SetMinMaxValues(0, 1)

    card.barBG = card.bar:CreateTexture(nil, "BACKGROUND")
    card.barBG:SetAllPoints(card.bar)
    card.barBG:SetColorTexture(0.20, 0.20, 0.22, 0.9)

    -- status label (bottom-right, above the bar)
    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("BOTTOMRIGHT", -12, 18)

    -- fill % (bottom-left, above the bar)
    card.fill = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.fill:SetPoint("BOTTOMLEFT", 12, 18)

    return card
end

--------------------------------------------------------------------------------
-- Panel + dropdown (created lazily)
--------------------------------------------------------------------------------
local panel, dropdown
local cards = {}
local emptyText

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

local function EnsurePanel()
    if panel then return end

    panel = CreateFrame("Frame", "RecommendedStatsPanel", CharacterFrame, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + (CARD_H + CARD_GAP) * 4 + 6)
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 6, -4)
    StyleBackdrop(panel, 0.05, 0.05, 0.06, 0.95, 0, 0, 0)

    RS.statPanel = panel -- so BiSWindow.lua can dock next to this instead of off-screen to the left

    -- title (shares the header row with the dropdown, so keep it to one line)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("LEFT", panel, "TOPLEFT", 12, -22)
    panel.title:SetWidth(PANEL_W - 12 - 120 - 8 - 8) -- leaves room for the dropdown
    panel.title:SetJustifyH("LEFT")
    panel.title:SetText("Recommended Stats")

    BuildDropdown()

    -- stat cards
    local top = -HEADER_H
    for i = 1, 4 do
        local card = CreateCard(panel, i)
        card:SetPoint("TOPLEFT", 12, top - (i - 1) * (CARD_H + CARD_GAP))
        cards[i] = card
    end

    -- empty / no-data message
    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -HEADER_H - 20)
    emptyText:SetWidth(PANEL_W - 30)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------
local function ShowEmpty(msg)
    for _, card in ipairs(cards) do card:Hide() end
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

    for i, card in ipairs(cards) do
        local row = data[i]
        if not row then card:Hide()
        else
            card:Show()
            local col = COLOR[row.state]

            card.accent:SetColorTexture(col[1], col[2], col[3], 1)
            card.name:SetText(STAT_LABEL[row.name] or row.name)
            card.current:SetText(string.format("%.2f%%", row.current))
            card.target:SetText(string.format("target : %.0f%%", row.target))

            local frac = row.current / math.max(row.target, 0.01)
            card.bar:SetValue(math.min(frac, 1))
            card.bar:SetStatusBarColor(col[1], col[2], col[3])

            if frac >= 1 and row.state ~= "on" then
                card.fill:SetText("100%+")
            else
                card.fill:SetText(string.format("%d%%", math.floor(math.min(frac, 1) * 100)))
            end

            local s = STATUS[row.state]
            card.status:SetText((s.arrow ~= "" and (s.arrow .. " ") or "") .. s.text)
            card.status:SetTextColor(col[1], col[2], col[3])
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