-- RecommendedStats :: UI/BiSWindow.lua
-- Lists BiS gear per slot for the current class/spec/content, docked to the right of
-- the stat panel (both live on the character sheet's right side; the screen's left
-- edge is right next to the character frame, so there's no room to mirror it there).
-- Item links + hover tooltip only, no tooltip rewriting (12.x taint hazard flagged
-- in scope.md).
--
-- Depends on Core.lua providing:
--   RS:GetKey() / RS:SchemaOK() / RS.listeners / RS:Refresh()
--   RecommendedStatsData_BiS[key] = { [SLOT] = { itemID=, pct= }, ... }
--   RecommendedStatsData_RaidDifficulty[key] = "mythic"|"heroic"|"normal", RAID keys only —
--     which difficulty's clears the BiS set for that key actually came from. A raid can go
--     days without a single Mythic guild yet (most visible right after it unlocks), so the
--     node-side build falls back to Heroic/Normal rather than leaving the key empty; this is
--     how the panel tells players their BiS list isn't Mythic-sourced when that happens.
-- Depends on CharacterPanel.lua providing:
--   RS.statPanel (the stat panel frame, to dock alongside)

local RS = RecommendedStats

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W   = 280
local ROW_H     = 22
local ROW_GAP   = 3
local HEADER_H  = 34

local GOLD = { 1, 0.82, 0.15 }

-- A slot below the "most players agree" line isn't wrong, just less consensus — so it stays
-- a neutral color rather than reading as a warning the way the stat panel's "too low" does.
local PCT_HIGH_COLOR = { 0.32, 0.85, 0.48 }
local PCT_HIGH_THRESHOLD = 65

-- Cosmetic-only slots (SHIRT, TABARD) are in the data but don't affect character
-- power, so they're left out of the BiS list.
local SLOT_ORDER = {
    "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST",
    "HANDS", "WAIST", "LEGS", "FEET",
    "FINGER_1", "FINGER_2", "TRINKET_1", "TRINKET_2",
    "MAIN_HAND", "OFF_HAND",
}
local SLOT_LABEL = {
    HEAD = "Head", NECK = "Neck", SHOULDER = "Shoulder", BACK = "Back", CHEST = "Chest",
    WRIST = "Wrist", HANDS = "Hands", WAIST = "Waist", LEGS = "Legs", FEET = "Feet",
    FINGER_1 = "Ring 1", FINGER_2 = "Ring 2", TRINKET_1 = "Trinket 1", TRINKET_2 = "Trinket 2",
    MAIN_HAND = "Main Hand", OFF_HAND = "Off Hand",
}

local QUESTION_MARK_ICON = 134400 -- INV_Misc_QuestionMark, placeholder while the item loads

-- Shown next to the "% of top N" line only when a RAID key's BiS set didn't come from Mythic
-- clears (see RecommendedStatsData_RaidDifficulty in the header comment above) — same amber as
-- the stat panel's "too low" state, since it's the same kind of "heads up, not the real target" cue.
local DIFFICULTY_LABEL = { heroic = "Heroic", normal = "Normal" }
local FALLBACK_COLOR = { 0.95, 0.65, 0.3 }

--------------------------------------------------------------------------------
-- Backdrop helper (same pattern as CharacterPanel.lua)
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
-- Build one slot row
--------------------------------------------------------------------------------
local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(PANEL_W - 24, ROW_H)

    -- quality-tinted ring behind the icon (colored via item:GetItemQuality() once it loads) —
    -- slightly larger than the icon so it reads as a border, not a background fill
    row.iconBorder = row:CreateTexture(nil, "BACKGROUND")
    row.iconBorder:SetSize(20, 20)
    row.iconBorder:SetPoint("LEFT", 0, 0)
    row.iconBorder:SetColorTexture(1, 1, 1, 0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("CENTER", row.iconBorder, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.slotLabel:SetPoint("LEFT", row.iconBorder, "RIGHT", 8, 0)
    row.slotLabel:SetWidth(56)
    row.slotLabel:SetJustifyH("LEFT")

    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemName:SetPoint("LEFT", row.slotLabel, "RIGHT", 4, 0)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)

    row.pct = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.pct:SetPoint("RIGHT", 0, 0)
    row.pct:SetWidth(34)
    row.pct:SetJustifyH("RIGHT")

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)
    row:SetHighlightTexture(highlight)

    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

--------------------------------------------------------------------------------
-- Panel (created lazily)
--------------------------------------------------------------------------------
local panel, rows = nil, {}
local emptyText

local function DefaultAnchor()
    panel:ClearAllPoints()
    if RS.statPanel then
        panel:SetPoint("TOPLEFT", RS.statPanel, "TOPRIGHT", 6, 0)
    else
        -- Fallback if CharacterPanel.lua hasn't built its panel yet (shouldn't happen given TOC load order).
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 292, -4)
    end
end

local function EnsurePanel()
    if panel then return end

    -- Parented to UIParent, same reasoning as the stat panel: don't inherit whatever
    -- layout surgery Chonky/MyCharacterSheet perform on CharacterFrame. Docks next to
    -- the stat panel by default but can be dragged off on its own.
    panel = CreateFrame("Frame", "RecommendedStatsBiSPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + (#SLOT_ORDER * (ROW_H + ROW_GAP)) + 14)
    StyleBackdrop(panel, 0.043, 0.047, 0.063, 0.97, 0.25, 0.27, 0.33, 0.7)

    RS:MakeMovable(panel, "bisPanelPos", DefaultAnchor)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 12, -12)
    panel.title:SetText("BiS Gear")
    panel.title:SetTextColor(unpack(GOLD))

    panel.subLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.subLabel:SetPoint("TOPRIGHT", -12, -14) -- text set by Render(), which always runs right after this

    local top = -HEADER_H
    for i in ipairs(SLOT_ORDER) do
        local row = CreateRow(panel)
        row:SetPoint("TOPLEFT", 12, top - (i - 1) * (ROW_H + ROW_GAP))
        rows[i] = row
    end

    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -HEADER_H - 16)
    emptyText:SetWidth(PANEL_W - 30)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------
local function ShowEmpty(msg)
    for _, row in ipairs(rows) do row:Hide() end
    emptyText:SetText(msg)
    emptyText:Show()
end

local function SetRowItem(row, itemID, pct)
    row.itemID = itemID
    row.pct:SetText(pct and (pct .. "%") or "")
    if pct and pct >= PCT_HIGH_THRESHOLD then
        row.pct:SetTextColor(unpack(PCT_HIGH_COLOR))
    else
        row.pct:SetTextColor(0.62, 0.62, 0.66)
    end
    row.itemName:SetText("...")
    row.icon:SetTexture(QUESTION_MARK_ICON)
    row.iconBorder:SetColorTexture(1, 1, 1, 0.25)

    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        row.itemName:SetText(item:GetItemLink() or item:GetItemName() or ("Item " .. itemID))
        row.icon:SetTexture(item:GetItemIcon())
        local r, g, b = C_Item.GetItemQualityColor(item:GetItemQuality())
        if r then row.iconBorder:SetColorTexture(r, g, b, 0.9) end
    end)
end

local function Render()
    -- Recomputed stats/gear must not force the panel into existence — only
    -- RS:SyncVisibility() (character frame open, minimap toggle, or restoring a
    -- standalone session) creates/shows it.
    if not panel then return end

    if not RS:SchemaOK() then
        ShowEmpty("Stat data is out of date for this addon version. Please update.")
        return
    end

    local key = RS:GetKey()
    local bis = key and RecommendedStatsData_BiS[key]
    if not bis then
        ShowEmpty("No BiS data for your current spec + content yet.")
        return
    end

    local m = RecommendedStatsData_Meta
    local difficulty = RecommendedStatsData_RaidDifficulty and RecommendedStatsData_RaidDifficulty[key]
    local fallbackLabel = difficulty and DIFFICULTY_LABEL[difficulty]
    if fallbackLabel then
        panel.subLabel:SetFormattedText("%% of top %d \194\183 %s (no Mythic logs yet)", m and m.sampleSize or 0, fallbackLabel)
        panel.subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    else
        panel.subLabel:SetFormattedText("%% of top %d", m and m.sampleSize or 0)
        panel.subLabel:SetTextColor(0.62, 0.62, 0.66)
    end

    emptyText:Hide()
    for i, slot in ipairs(SLOT_ORDER) do
        local row = rows[i]
        local entry = bis[slot]
        if not entry then
            row:Hide()
        else
            row:Show()
            row.slotLabel:SetText(SLOT_LABEL[slot] or slot)
            SetRowItem(row, entry.itemID, entry.pct)
        end
    end
end

table.insert(RS.listeners, Render)

--------------------------------------------------------------------------------
-- Visibility: attach mode + minimap toggle + the "show BiS section" option all
-- drive this, not the character frame directly (see RS:ShouldShowPanels() in
-- Core.lua).
--------------------------------------------------------------------------------
local function SyncVisibility()
    if RS:ShouldShowPanels() and RS:GetShowBiS() then
        EnsurePanel()
        RS:RedockIfDefault("bisPanelPos") -- follow the stat panel if it moved, unless dragged elsewhere
        panel:Show()
        Render()
    elseif panel then
        panel:Hide()
    end
end
table.insert(RS.visibilitySyncers, SyncVisibility)

CharacterFrame:HookScript("OnShow", SyncVisibility)
CharacterFrame:HookScript("OnHide", SyncVisibility)
