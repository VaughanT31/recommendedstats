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
-- Depends on CharacterPanel.lua providing:
--   RS.statPanel (the stat panel frame, to dock alongside)

local RS = RecommendedStats

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W   = 280
local ROW_H     = 20
local ROW_GAP   = 2
local HEADER_H  = 34

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

--------------------------------------------------------------------------------
-- Backdrop helper (same pattern as CharacterPanel.lua)
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
-- Build one slot row
--------------------------------------------------------------------------------
local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(PANEL_W - 24, ROW_H)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.slotLabel:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
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

local function EnsurePanel()
    if panel then return end

    panel = CreateFrame("Frame", "RecommendedStatsBiSPanel", CharacterFrame, "BackdropTemplate")
    panel:SetSize(PANEL_W, HEADER_H + (#SLOT_ORDER * (ROW_H + ROW_GAP)) + 14)
    if RS.statPanel then
        panel:SetPoint("TOPLEFT", RS.statPanel, "TOPRIGHT", 6, 0)
    else
        -- Fallback if CharacterPanel.lua hasn't built its panel yet (shouldn't happen given TOC load order).
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 292, -4)
    end
    StyleBackdrop(panel, 0.05, 0.05, 0.06, 0.95, 0, 0, 0)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 12, -12)
    panel.title:SetText("BiS Gear")

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
    row.itemName:SetText("...")
    row.icon:SetTexture(QUESTION_MARK_ICON)

    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        row.itemName:SetText(item:GetItemLink() or item:GetItemName() or ("Item " .. itemID))
        row.icon:SetTexture(item:GetItemIcon())
    end)
end

local function Render()
    EnsurePanel()

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
-- Show with the character sheet; refresh on open
--------------------------------------------------------------------------------
CharacterFrame:HookScript("OnShow", function()
    EnsurePanel()
    Render()
end)
