-- RecommendedStats :: UI/BiSWindow.lua
-- Lists BiS gear per slot for the current class/spec/content. Renders into RS.bisPage — an
-- empty content frame created by UI/CharacterPanel.lua (the merged window's host), which also
-- owns the "BiS Gear" tab button that shows/hides this page. This file no longer owns any
-- top-level frame, movable/escape-close/CharacterFrame-hook lifecycle of its own.
-- Item links + hover tooltip only, no tooltip rewriting (12.x taint hazard flagged
-- in scope.md).
--
-- Depends on Core.lua providing:
--   RS:GetKey() / RS:SchemaOK() / RS.listeners / RS:Refresh() / RS:DaysSince()
--   RS:GetActiveTab() / RS.tabSyncers / RS:GetShowBiS()
--   RS:GetSampleSizeFor(key) / RS:IsSampleSizeLow(key)
--   RecommendedStatsData_BiS[key] = { [SLOT] = entry, ... }, where entry is:
--     itemID, pct           -- the #1 pick and its share of the top players
--     bonusIDs              -- (optional) real bonus_list off a top player's equipped copy,
--                               see RecommendedStatsNode/src/bnet.js's extractGear
--     altItemID, altPct, altBonusIDs -- (optional) runner-up pick, same shape (aggregate.js)
--     source = { raidSlug, raidDifficulty } -- (optional, RAID keys only) majority-voted raid
--                               roster the item's wearers were crawled from
--     changedAt              -- "YYYY-MM-DD" the #1 pick last actually changed (bisHistory.js)
--   RecommendedStatsData_RaidDifficulty[key] = "mythic"|"heroic"|"normal", RAID keys only —
--     which difficulty's clears the BiS set for that key actually came from. A raid can go
--     days without a single Mythic guild yet (most visible right after it unlocks), so the
--     node-side build falls back to Heroic/Normal rather than leaving the key empty; this is
--     how the panel tells players their BiS list isn't Mythic-sourced when that happens.
-- Depends on CharacterPanel.lua providing:
--   RS.bisPage (this file's content parent, sized and positioned by that file)

local RS = RecommendedStats

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W    = 360 -- must match CharacterPanel.lua's PANEL_W (RS.bisPage spans the full window width)
local ROW_H      = 22
local ROW_GAP    = 3
local SUBLABEL_H = 18 -- small header row for the "% of top N" line (no title here — the tab button already reads "BiS Gear")

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

-- Standard PaperDoll inventory slot IDs (stable since vanilla) — used to read the player's
-- currently equipped item per BiS slot for the status dot below. Hardcoded rather than the
-- INVSLOT_* globals since HANDS in particular is INVSLOT_HAND (singular) and easy to typo.
local SLOT_TO_INVSLOT = {
    HEAD = 1, NECK = 2, SHOULDER = 3, BACK = 15, CHEST = 5, WRIST = 9,
    HANDS = 10, WAIST = 6, LEGS = 7, FEET = 8,
    FINGER_1 = 11, FINGER_2 = 12, TRINKET_1 = 13, TRINKET_2 = 14,
    MAIN_HAND = 16, OFF_HAND = 17,
}

-- Status dot: green if the player has the #1 BiS pick equipped, yellow for the runner-up
-- (entry.altItemID — see aggregate.js), red for neither. Base itemID only, ignoring upgrade
-- rank — that distinction already lives in the pct/ilvl shown elsewhere on the row.
local DOT_TEXTURE = {
    bis = "Interface\\COMMON\\Indicator-Green",
    alt = "Interface\\COMMON\\Indicator-Yellow",
    missing = "Interface\\COMMON\\Indicator-Red",
}

-- How recently a slot's #1 pick must have changed (Data/BiS.lua's entry.changedAt, stamped by
-- the Node build's bisHistory.js) to still show the "NEW" tag.
local NEW_TAG_DAYS = 7

-- Shown next to the "% of top N" line only when a RAID key's BiS set didn't come from Mythic
-- clears (see RecommendedStatsData_RaidDifficulty in the header comment above) — same amber as
-- the stat panel's "too low" state, since it's the same kind of "heads up, not the real target" cue.
local DIFFICULTY_LABEL = { heroic = "Heroic", normal = "Normal" }
local FALLBACK_COLOR = { 0.95, 0.65, 0.3 }

-- "the-tidebound-grotto" -> "The Tidebound Grotto" — entry.source.raidSlug/raidDifficulty
-- (aggregate.js) are RIO/Blizzard slugs, not display names; this is the whole raid list's
-- naming convention (kebab-case of the real name), so title-casing is accurate rather than
-- a guess, unlike trying to attribute a specific boss (see aggregate.js's raidSourceCounts
-- comment for why per-encounter attribution isn't available from this data at all).
local function TitleCase(slug)
    local words = {}
    for w in slug:gmatch("[^%-]+") do
        words[#words + 1] = w:sub(1, 1):upper() .. w:sub(2)
    end
    return table.concat(words, " ")
end

--------------------------------------------------------------------------------
-- Build one slot row
--------------------------------------------------------------------------------
local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(PANEL_W - 24, ROW_H)
    row:RegisterForClicks("LeftButtonUp")

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

    -- Green/yellow/red equipped-vs-BiS status dot — see SLOT_TO_INVSLOT/DOT_TEXTURE above.
    row.statusDot = row:CreateTexture(nil, "OVERLAY")
    row.statusDot:SetSize(7, 7)
    row.statusDot:SetPoint("LEFT", row.iconBorder, "RIGHT", 2, 0)

    row.slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.slotLabel:SetPoint("LEFT", row.statusDot, "RIGHT", 5, 0)
    row.slotLabel:SetWidth(51)
    row.slotLabel:SetJustifyH("LEFT")

    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemName:SetPoint("LEFT", row.slotLabel, "RIGHT", 4, 0)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)

    -- Short-lived tag for a slot whose #1 pick changed recently (entry.changedAt) — see
    -- NEW_TAG_DAYS above.
    row.newTag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.newTag:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    row.newTag:SetWidth(24)
    row.newTag:SetJustifyH("RIGHT")
    row.newTag:SetText("NEW")
    row.newTag:SetTextColor(unpack(GOLD))
    row.newTag:Hide()

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
        -- self.itemLink (when set) carries this item's real bonus IDs — see BuildItemLink — so the
        -- hover tooltip matches the itemized copy actually shown in the row, not the base template.
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        else
            GameTooltip:SetItemByID(self.itemID)
        end
        if self.sourceText then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.sourceText, 0.6, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Shift-click links the item in chat; the Dress Up modified-click previews it — both read
    -- the user's own modified-click bindings (IsModifiedClick) rather than hardcoding Shift/Ctrl.
    row:SetScript("OnClick", function(self)
        if not self.itemID then return end
        if IsModifiedClick("DRESSUP") then
            DressUpItemLink(self.decoratedLink or self.itemLink or self.itemID)
        elseif IsModifiedClick("CHATLINK") and self.decoratedLink then
            ChatEdit_InsertLink(self.decoratedLink)
        end
    end)

    return row
end

--------------------------------------------------------------------------------
-- Content (built lazily into RS.bisPage)
--------------------------------------------------------------------------------
local page, rows = nil, {}
local emptyText

local function EnsureContent()
    if page then return end
    page = RS.bisPage
    if not page then return end -- CharacterPanel.lua hasn't built the merged window yet this pass

    page.subLabel = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.subLabel:SetPoint("TOPRIGHT", -12, -2) -- text set by Render(), which always runs right after this

    local top = -SUBLABEL_H
    for i in ipairs(SLOT_ORDER) do
        local row = CreateRow(page)
        row:SetPoint("TOPLEFT", 12, top - (i - 1) * (ROW_H + ROW_GAP))
        rows[i] = row
    end

    emptyText = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -SUBLABEL_H - 16)
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

-- itemID alone always resolves to an item's raw base template in retail (its lowest possible ilvl,
-- sometimes with placeholder/negative stats) — bonus IDs are how the client encodes which upgrade
-- track/rank (Champion/Hero/Myth, or a raid's LFR/Normal/Heroic/Mythic itemization) a specific drop
-- actually is. entry.bonusIDs comes from the Node build capturing bonus_list off a real top player's
-- equipped copy of the item (RecommendedStatsNode/src/bnet.js's extractGear) — when it's missing
-- (older cached data, or an item that genuinely has none) this returns nil and callers fall back to
-- the bare itemID.
--
-- Field order per Wowpedia's "itemString": item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:
-- linkLevel:specID:upgradeType:difficultyID:numBonusIDs:bonus1:...:bonusN
local function BuildItemLink(itemID, bonusIDs)
    if not bonusIDs or #bonusIDs == 0 then return nil end
    local fields = { itemID, "", "", "", "", "", "", "", "", "", "", "", #bonusIDs }
    for _, b in ipairs(bonusIDs) do fields[#fields + 1] = b end
    return "item:" .. table.concat(fields, ":")
end

-- Item:GetItemLink() on an item built via Item:CreateFromItemLink just echoes back whatever raw
-- itemString it was constructed from (no color/name wrapper) instead of building a proper display
-- link the way it does for Item:CreateFromItemID — that's the "item:250060:::::::::::N..." garbage
-- that showed up in every row once BiS entries started carrying bonus IDs. GetItemName()/
-- GetItemQuality() don't have that quirk (there's no raw input to echo for either), so this
-- reconstructs a normal `|cffXXXXXX|Hitem:...|h[Name]|h|r` hyperlink by hand from those instead.
local function BuildDecoratedLink(itemLink, name, quality)
    if not itemLink or not name then return nil end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local hex = (color and color.hex) or "ffffffff"
    return "|c" .. hex .. "|H" .. itemLink .. "|h[" .. name .. "]|h|r"
end

local function SetRowItem(row, slot, entry)
    local itemID, pct = entry.itemID, entry.pct
    row.itemID = itemID
    row.itemLink = BuildItemLink(itemID, entry.bonusIDs)
    row.decoratedLink = nil -- filled in once the async item load below resolves
    row.pct:SetText(pct and (pct .. "%") or "")
    if pct and pct >= PCT_HIGH_THRESHOLD then
        row.pct:SetTextColor(unpack(PCT_HIGH_COLOR))
    else
        row.pct:SetTextColor(0.62, 0.62, 0.66)
    end
    row.itemName:SetText("...")
    row.icon:SetTexture(QUESTION_MARK_ICON)
    row.iconBorder:SetColorTexture(1, 1, 1, 0.25)

    -- Status dot: compare the player's currently equipped item in this slot against the #1 pick
    -- (green) or the runner-up (yellow, entry.altItemID from aggregate.js) — base itemID only,
    -- ignoring upgrade rank, which is a separate concern already shown via pct/tooltip ilvl.
    local invSlot = SLOT_TO_INVSLOT[slot]
    local equippedID = invSlot and GetInventoryItemID("player", invSlot)
    if equippedID == itemID then
        row.statusDot:SetTexture(DOT_TEXTURE.bis)
    elseif entry.altItemID and equippedID == entry.altItemID then
        row.statusDot:SetTexture(DOT_TEXTURE.alt)
    else
        row.statusDot:SetTexture(DOT_TEXTURE.missing)
    end

    local age = entry.changedAt and RS:DaysSince(entry.changedAt)
    row.newTag:SetShown(age ~= nil and age <= NEW_TAG_DAYS)

    if entry.source then
        row.sourceText = "Source: " .. TitleCase(entry.source.raidSlug) ..
            (entry.source.raidDifficulty and (" (" .. TitleCase(entry.source.raidDifficulty) .. ")") or "")
    else
        row.sourceText = nil
    end

    local item = row.itemLink and Item:CreateFromItemLink(row.itemLink) or Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local name = item:GetItemName() or ("Item " .. itemID)
        local quality = item:GetItemQuality()
        row.itemName:SetText(name)
        row.decoratedLink = BuildDecoratedLink(row.itemLink or ("item:" .. itemID), name, quality)
        row.icon:SetTexture(item:GetItemIcon())
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then row.iconBorder:SetColorTexture(r, g, b, 0.9) end
    end)
end

local function Render()
    -- Recomputed stats/gear must not force the content into existence — only
    -- RS:SyncVisibility() (character frame open, minimap toggle, or restoring a
    -- standalone session) builds it (see EnsureContent above).
    if not page then return end

    if not RS:SchemaOK() then
        ShowEmpty("Stat data is out of date for this addon version. Please update.")
        return
    end

    local key = RS:GetKey()
    local bis = key and RecommendedStatsData_BiS[key]
    -- A key can exist as a non-nil but EMPTY table when the Node build verified candidates for
    -- it but couldn't extract gear for any of them (see RecommendedStatsNode's dropStaleGear) —
    -- `not bis` alone misses that case, since an empty table is still truthy in Lua.
    if not bis or not next(bis) then
        ShowEmpty("No BiS data for your current spec + content yet.")
        return
    end

    -- The pct on each row below is already computed against the real per-key sample (see
    -- aggregate.js's `100 * bestN / top.length`) — this label used to always claim "top N"
    -- using the configured target regardless, which overstated confidence for a key built from
    -- far fewer players. RS:GetSampleSizeFor falls back to the target when the per-key count
    -- isn't available (older data, or a placeholder SampleSize.lua) so the label never goes blank.
    local m = RecommendedStatsData_Meta
    local n = RS:GetSampleSizeFor(key) or (m and m.sampleSize) or 0
    local difficulty = RecommendedStatsData_RaidDifficulty and RecommendedStatsData_RaidDifficulty[key]
    local fallbackLabel = difficulty and DIFFICULTY_LABEL[difficulty]
    if fallbackLabel then
        page.subLabel:SetFormattedText("%% of top %d \194\183 %s (no Mythic logs yet)", n, fallbackLabel)
        page.subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    elseif RS:IsSampleSizeLow(key) then
        page.subLabel:SetFormattedText("%% of top %d (fewer than usual)", n)
        page.subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    else
        page.subLabel:SetFormattedText("%% of top %d", n)
        page.subLabel:SetTextColor(0.62, 0.62, 0.66)
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
            SetRowItem(row, slot, entry)
        end
    end
end

table.insert(RS.listeners, Render)

--------------------------------------------------------------------------------
-- Visibility: lazily build content once the merged window exists; showing/hiding
-- this page based on the active tab is CharacterPanel.lua's job (RS.tabSyncers),
-- since it also owns the "BiS Gear" tab button.
--------------------------------------------------------------------------------
local function SyncVisibility()
    EnsureContent()
end
table.insert(RS.visibilitySyncers, SyncVisibility)

local function SyncTab()
    if not page then return end
    if RS:GetActiveTab() == "BIS" and RS:GetShowBiS() then
        page:Show()
    else
        page:Hide()
    end
end
table.insert(RS.tabSyncers, SyncTab)
