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
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PANEL_W    = 400 -- must match CharacterPanel.lua's PANEL_W (RS.bisPage spans the full window width)
-- 32, not the original 22 — leaves room for the enchant/gem sub-line under the item name
-- (row.subLine, see CreateRow/SetRowItem below). CharacterPanel.lua no longer hand-syncs a
-- duplicate constant for this — see RS:GetBisContentHeight() below, which computes it from
-- ROW_H/ROW_GAP/SLOT_ORDER directly so the two files can't drift out of sync again the way they
-- did the first time this row height changed (see the original hand-synced BIS_CONTENT_H bug).
local ROW_H      = 32
local ROW_GAP    = 3
local SUBLABEL_H = 18 -- small header row for the "% of top N" / tier-set line (no title here — the tab button already reads "BiS Gear")

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
    HEAD = L.SLOT_HEAD, NECK = L.SLOT_NECK, SHOULDER = L.SLOT_SHOULDER, BACK = L.SLOT_BACK, CHEST = L.SLOT_CHEST,
    WRIST = L.SLOT_WRIST, HANDS = L.SLOT_HANDS, WAIST = L.SLOT_WAIST, LEGS = L.SLOT_LEGS, FEET = L.SLOT_FEET,
    FINGER_1 = L.SLOT_FINGER_1, FINGER_2 = L.SLOT_FINGER_2, TRINKET_1 = L.SLOT_TRINKET_1, TRINKET_2 = L.SLOT_TRINKET_2,
    MAIN_HAND = L.SLOT_MAIN_HAND, OFF_HAND = L.SLOT_OFF_HAND,
}

-- Exact content height needed for every SLOT_ORDER row plus the sub-header row — called by
-- CharacterPanel.lua (which owns RS.bisPage's actual frame/SetHeight) instead of that file
-- hand-typing its own copy of this arithmetic, which is what let the two drift out of sync the
-- first time ROW_H changed above. Safe to call from another file at runtime despite this file
-- loading after CharacterPanel.lua in the .toc — CharacterPanel.lua only ever calls this from
-- inside EnsurePanel/SyncTabUI, which don't run until well after every file has finished loading.
function RS:GetBisContentHeight()
    return SUBLABEL_H + (#SLOT_ORDER * (ROW_H + ROW_GAP)) + 8
end

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

-- Status dot: green if the player has the #1 BiS pick equipped. Yellow covers two cases now —
-- the runner-up (entry.altItemID, aggregate.js) OR the player's own item being at least as
-- strong by ilvl (entry.ilvl, a real top player's equipped copy) even though it's a different
-- itemID — this used to be exact-itemID-only, which read a same-or-better item in a different
-- form as "missing". Red is neither. See SetRowItem below for where the ilvl comparison happens.
local DOT_TEXTURE = {
    bis = "Interface\\COMMON\\Indicator-Green",
    alt = "Interface\\COMMON\\Indicator-Yellow",
    missing = "Interface\\COMMON\\Indicator-Red",
}
-- Colorblind mode (RS:GetColorblindMode(), Core.lua): shape-distinct textures instead of
-- color-only dots. These are long-established Blizzard raid-frame ready-check textures (still
-- colored, just also shaped) rather than a custom asset that would need its own verification.
local DOT_TEXTURE_CB = {
    bis = "Interface\\RaidFrame\\ReadyCheck-Ready",
    alt = "Interface\\RaidFrame\\ReadyCheck-Waiting",
    missing = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

-- Enchant/gem sub-line colors — green/red mirror the stat panel's on/under colors
-- (CharacterPanel.lua's COLOR table) for the same "good/needs attention" meaning; grey is used
-- when the slot has no enchant/gem recommendation to compare against at all.
local SUBLINE_OK_COLOR      = { 0.32, 0.85, 0.48 }
local SUBLINE_MISSING_COLOR = { 0.92, 0.35, 0.35 }

-- How recently a slot's #1 pick must have changed (Data/BiS.lua's entry.changedAt, stamped by
-- the Node build's bisHistory.js) to still show the "NEW" tag.
local NEW_TAG_DAYS = 7

-- Shown next to the "% of top N" line only when a RAID key's BiS set didn't come from Mythic
-- clears (see RecommendedStatsData_RaidDifficulty in the header comment above) — same amber as
-- the stat panel's "too low" state, since it's the same kind of "heads up, not the real target" cue.
local DIFFICULTY_LABEL = { heroic = L.DIFFICULTY_HEROIC, normal = L.DIFFICULTY_NORMAL }
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
    -- TOPRIGHT, not TOP: "TOP" anchors to slotLabel's horizontal CENTER, not its right edge —
    -- that put itemName's left edge halfway through slotLabel's own text, rendering them
    -- overlapping/on top of each other instead of side by side. Confirmed live.
    row.itemName:SetPoint("TOPLEFT", row.slotLabel, "TOPRIGHT", 4, 6)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)

    -- Enchant/gem status, e.g. "Enchant +  \194\183  Gem x" — populated by SetRowItem below,
    -- hidden entirely when the slot has neither an enchant nor a gem recommendation to compare
    -- against (RecommendedStatsData_BiS[key][slot].enchantID/.gemID).
    row.subLine = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.subLine:SetPoint("TOPLEFT", row.itemName, "BOTTOMLEFT", 0, -2)
    row.subLine:SetJustifyH("LEFT")

    -- Short-lived tag for a slot whose #1 pick changed recently (entry.changedAt) — see
    -- NEW_TAG_DAYS above. Width bumped from the original 24 to 30: "NEW" at this font size was
    -- getting clipped to "N..." — confirmed live once a fresh full data rebuild left every row
    -- flagged as recently-changed at once, which is when a too-narrow width like this actually
    -- shows up (a single stray NEW tag is easy to miss; every row at once isn't).
    row.newTag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.newTag:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    row.newTag:SetWidth(30)
    row.newTag:SetJustifyH("RIGHT")
    row.newTag:SetText(L.NEW_TAG)
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

    -- Tier-set 2pc/4pc line, top-left of the same header row as subLabel above (no extra vertical
    -- space needed — SUBLABEL_H's 18px already fits both). Hidden when RecommendedStatsData_TierSet
    -- has nothing for this key (config.tierSetItemIDs not yet populated for this class, see
    -- RecommendedStatsNode/config.js) — see Render() below for where it's populated.
    page.tierLine = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.tierLine:SetPoint("TOPLEFT", 12, -2)
    page.tierLine:Hide()

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

-- Counts how many of the current tier set's itemIDs (RecommendedStatsData_TierSet[key].itemIDs,
-- RecommendedStatsNode/config.js's tierSetItemIDs) the player currently has equipped, across
-- every inventory slot rather than just the armor slots BiS tracks — a tier token could in
-- principle occupy any of them.
local function CountEquippedTierPieces(itemIDs)
    if not itemIDs or #itemIDs == 0 then return 0 end
    local set = {}
    for _, id in ipairs(itemIDs) do set[id] = true end
    local count = 0
    for invSlot = 1, 19 do
        local id = GetInventoryItemID("player", invSlot)
        if id and set[id] then count = count + 1 end
    end
    return count
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

local function ColorHex(col)
    return ("|cff%02x%02x%02x"):format(
        math.floor(col[1] * 255 + 0.5), math.floor(col[2] * 255 + 0.5), math.floor(col[3] * 255 + 0.5)
    )
end

-- Reads the enchant/gem IDs actually applied to the player's own equipped item, straight off its
-- itemString (item:itemID:enchantID:gem1:gem2:gem3:gem4:...) — this field order has been stable
-- since the itemString format was introduced, unlike e.g. bonusIDs' meaning which shifts with
-- upgrade systems, so this doesn't need a ⚠ VERIFY the way newer fields elsewhere in this addon do.
local function ParseEquippedEnchantAndGems(itemLink)
    if not itemLink then return nil, nil end
    local itemString = itemLink:match("item[%-?%d:]+")
    if not itemString then return nil, nil end
    local fields = {}
    for field in itemString:gmatch("[^:]+") do fields[#fields + 1] = field end
    local enchantID = tonumber(fields[3])
    local gemIDs = {}
    for i = 4, 7 do
        local g = tonumber(fields[i])
        if g and g > 0 then gemIDs[#gemIDs + 1] = g end
    end
    return (enchantID and enchantID > 0) and enchantID or nil, gemIDs
end

-- Builds the "Enchant + \194\183 Gem x" sub-line — green "+" when the player's own equipped item
-- matches the recommended enchant/gem for this slot (entry.enchantID/entry.gemID, aggregate.js's
-- per-slot popularity vote — see that file for why it's tracked per slot rather than tied to the
-- specific BiS item), red "x" otherwise. Plain ASCII, not a Unicode check/x mark: WoW's default
-- client fonts don't cover that block (confirmed live — it rendered as a tofu box), the same
-- issue as CharacterPanel.lua's colorblind status glyphs. A slot with no recommendation for one
-- or the other (e.g. no gem socket exists) simply omits that half rather than showing red.
local function BuildSubLine(entry, equippedEnchantID, equippedGemIDs)
    local parts = {}
    if entry.enchantID then
        local has = equippedEnchantID == entry.enchantID
        parts[#parts + 1] = ColorHex(has and SUBLINE_OK_COLOR or SUBLINE_MISSING_COLOR)
            .. L.BIS_ENCHANT_LABEL .. (has and "+" or "x") .. "|r"
    end
    if entry.gemID then
        local has = false
        for _, g in ipairs(equippedGemIDs or {}) do
            if g == entry.gemID then has = true; break end
        end
        parts[#parts + 1] = ColorHex(has and SUBLINE_OK_COLOR or SUBLINE_MISSING_COLOR)
            .. L.BIS_GEM_LABEL .. (has and "+" or "x") .. "|r"
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "  \194\183  ")
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

    -- Status dot: green for the exact #1 pick. Yellow covers the runner-up (entry.altItemID) OR
    -- the player's own item being at least as strong by ilvl (entry.ilvl, aggregate.js) even
    -- though it's a different itemID — widened from an exact-itemID-only check, which used to
    -- read a same-or-better item in a different form (a crafted/catalyst copy, a higher upgrade
    -- rank of something else) as "missing". Red is neither.
    local invSlot = SLOT_TO_INVSLOT[slot]
    local equippedID = invSlot and GetInventoryItemID("player", invSlot)
    local equippedLink = invSlot and GetInventoryItemLink("player", invSlot)
    local dotTex = RS:GetColorblindMode() and DOT_TEXTURE_CB or DOT_TEXTURE
    if equippedID == itemID then
        row.statusDot:SetTexture(dotTex.bis)
    elseif entry.altItemID and equippedID == entry.altItemID then
        row.statusDot:SetTexture(dotTex.alt)
    elseif equippedID and equippedID ~= 0 and entry.ilvl and equippedLink
        and (select(1, GetDetailedItemLevelInfo(equippedLink)) or 0) >= entry.ilvl then
        row.statusDot:SetTexture(dotTex.alt)
    else
        row.statusDot:SetTexture(dotTex.missing)
    end

    -- Enchant/gem sub-line (see BuildSubLine above) — reads what's actually applied to the
    -- player's own equipped item, not the BiS item's own enchant/gem, since the whole point is
    -- comparing the two.
    local equippedEnchantID, equippedGemIDs = ParseEquippedEnchantAndGems(equippedLink)
    local subLine = BuildSubLine(entry, equippedEnchantID, equippedGemIDs)
    row.subLine:SetShown(subLine ~= nil)
    if subLine then row.subLine:SetText(subLine) end

    local age = entry.changedAt and RS:DaysSince(entry.changedAt)
    row.newTag:SetShown(age ~= nil and age <= NEW_TAG_DAYS)

    if entry.source then
        local raidName = TitleCase(entry.source.raidSlug)
        row.sourceText = L.BIS_SOURCE_PREFIX .. (entry.source.raidDifficulty
            and L.BIS_SOURCE_WITH_DIFFICULTY:format(raidName, TitleCase(entry.source.raidDifficulty))
            or raidName)
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
        ShowEmpty(L.SCHEMA_OUT_OF_DATE)
        return
    end

    local key = RS:GetKey()
    local bis = key and RecommendedStatsData_BiS[key]
    -- A key can exist as a non-nil but EMPTY table when the Node build verified candidates for
    -- it but couldn't extract gear for any of them (see RecommendedStatsNode's dropStaleGear) —
    -- `not bis` alone misses that case, since an empty table is still truthy in Lua.
    if not bis or not next(bis) then
        ShowEmpty(L.NO_BIS_DATA_YET)
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
        page.subLabel:SetFormattedText(L.BIS_PCT_FALLBACK, n, fallbackLabel)
        page.subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    elseif RS:IsSampleSizeLow(key) then
        page.subLabel:SetFormattedText(L.BIS_PCT_LOW_SAMPLE, n)
        page.subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    else
        page.subLabel:SetFormattedText(L.BIS_PCT_PLAIN, n)
        page.subLabel:SetTextColor(0.62, 0.62, 0.66)
    end

    local tierData = RecommendedStatsData_TierSet and RecommendedStatsData_TierSet[key]
    if tierData and tierData.itemIDs and #tierData.itemIDs > 0 then
        local owned = CountEquippedTierPieces(tierData.itemIDs)
        page.tierLine:SetFormattedText(L.BIS_TIER_LINE, owned, tierData.pct4pc or 0)
        page.tierLine:SetTextColor(0.62, 0.62, 0.66)
        page.tierLine:Show()
    else
        page.tierLine:Hide()
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
