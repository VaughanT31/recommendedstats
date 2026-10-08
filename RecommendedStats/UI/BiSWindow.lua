-- RecommendedStats :: UI/BiSWindow.lua
-- Standalone BiS gear window (opened by the "BiS" button on the main panel, or /rs bis), same
-- kind of launcher as UI/TalentsWindow.lua and UI/RotationWindow.lua. Used to be a tab page
-- inside the main panel (RS.bisPage), which at 440px wide truncated item names and squeezed
-- every stat onto one line; out here the 16 slots sit in two columns and each item's secondary
-- stats are stacked one per line, with the recommended enchant/gem in their own sub-column.
-- Item links + hover tooltip only, no tooltip rewriting (12.x taint hazard flagged
-- in scope.md).
--
-- The Raid / Mythic+ toggle here drives the SAME setting as the stats panel's dropdown
-- (RS:GetContent()/RS:SetContent()), unlike the Talents window's independent one: BiS picks and
-- stat targets come from the same sampled players, so showing one content's gear next to the
-- other's targets would be misleading.
--
-- Depends on Core.lua providing:
--   RS:GetKey() / RS:SchemaOK() / RS.listeners / RS:Refresh() / RS:DaysSince()
--   RS:GetContent() / RS:SetContent(c) / RS:HasDataFor(c) / RS:GetShowBiS()
--   RS:MakeMovable() / RS.visibilitySyncers / RS.skinListeners
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

local RS = RecommendedStats
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Look & feel
--------------------------------------------------------------------------------
local PAD          = 16
local COL_W        = 420
local COL_GAP      = 24
local ROWS_PER_COL = 8
-- Tall enough for slot label + item name + three stacked stat lines (neck/rings roll three
-- secondaries; most other slots roll two and leave the third line empty).
local ROW_H        = 66
local ROW_GAP      = 6
local ICON_SZ      = 36
local TEXT_X       = ICON_SZ + 10 -- left edge of every text line in a row
local LINE_H       = 12
local STATS_Y      = -31          -- first stacked stat line (and first enchant/gem line)
local MAX_STAT_LINES = 3
local MODS_X       = 220          -- enchant/gem sub-column, right of the stacked stat lines
local HEADER_H     = 80           -- title + controls row, rows start below this
local CONTROLS_Y   = -44

local WIN_W = PAD * 2 + COL_W * 2 + COL_GAP
local WIN_H = HEADER_H + ROWS_PER_COL * (ROW_H + ROW_GAP) - ROW_GAP + PAD

local GOLD = { 1, 0.82, 0.15 }
local DIM  = { 0.62, 0.62, 0.66 }
local STAT_TEXT_COLOR = { 0.82, 0.82, 0.84 }
local DEFAULT_BORDER  = { 0.25, 0.27, 0.33 }
local TAB_ACTIVE_BG   = { 0.16, 0.17, 0.22, 1 }
local TAB_IDLE_BG     = { 0.043, 0.047, 0.063, 1 }

-- A slot below the "most players agree" line isn't wrong, just less consensus — so it stays
-- a neutral color rather than reading as a warning the way the stat panel's "too low" does.
local PCT_HIGH_COLOR = { 0.32, 0.85, 0.48 }
local PCT_HIGH_THRESHOLD = 65

-- Cosmetic-only slots (SHIRT, TABARD) are in the data but don't affect character
-- power, so they're left out of the BiS list. The first ROWS_PER_COL fill the left column,
-- the rest the right one, so reading order down-then-across matches the old single list.
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

-- Rating readouts (item's own stats, and what a recommended enchant/gem itself grants) — this
-- file owns its own copy of these rather than importing CharacterPanel.lua's, same "each file
-- owns its own layout locals independently" convention as the constants above.
local STAT_ORDER = { "haste", "crit", "mastery", "versatility" }
local SHORT_STAT_LABEL = {
    haste = L.STAT_HASTE_SHORT, crit = L.STAT_CRIT_SHORT, mastery = L.STAT_MASTERY_SHORT, versatility = L.STAT_VERSATILITY_SHORT,
}

local CONTENT_CHOICES = {
    { value = "RAID",       text = L.CONTENT_RAID },
    { value = "MYTHICPLUS", text = L.CONTENT_MYTHICPLUS },
}

local QUESTION_MARK_ICON = 134400 -- INV_Misc_QuestionMark, placeholder while the item loads
local ENCHANT_ICON = "Interface\\Icons\\INV_Enchant_Disenchant"

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

-- How recently a slot's #1 pick must have changed (Data/BiS.lua's entry.changedAt, stamped by
-- the Node build's bisHistory.js) to still show the "NEW" tag.
local NEW_TAG_DAYS = 7

-- Shown next to the "% of top N" line only when a RAID key's BiS set didn't come from Mythic
-- clears (see RecommendedStatsData_RaidDifficulty in the header comment above) — same amber as
-- the stat panel's "too low" state, since it's the same kind of "heads up, not the real target" cue.
local DIFFICULTY_LABEL = { heroic = L.DIFFICULTY_HEROIC, normal = L.DIFFICULTY_NORMAL }
local FALLBACK_COLOR = { 0.95, 0.65, 0.3 }

local function BorderColor()
    if RS:GetSkin() == "DEFAULT" then return DEFAULT_BORDER end
    return RS:GetAccentColor()
end

-- A flat edgeSize = 1 is one UI unit, not one screen pixel: below 1.0 UI scale that's under a
-- physical pixel, and on a window this wide the right edge could round away to nothing entirely
-- depending on where it sat. Snapping to the nearest real pixel (minimum one) keeps all four edges.
local function StyleBackdrop(frame)
    local edge = PixelUtil and PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1) or 1
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = edge })
    frame:SetBackdropColor(0.043, 0.047, 0.063, 0.97)
    local b = BorderColor()
    frame:SetBackdropBorderColor(b[1], b[2], b[3], 0.7)
end

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
-- Rating readouts — the item's own granted stats, and what a recommended enchant/gem itself
-- grants (RecommendedStatsData_BiS[key][slot].enchantID/.gemID, aggregate.js's per-slot vote).
-- This is the addon's answer to "just show me the rating, gear is itemized in rating, not %" —
-- the existing % targets stay the primary readout on the Stats tab, this is additive detail here.
--------------------------------------------------------------------------------

-- ⚠ VERIFY these exact key names live — Blizzard's internal ITEM_MOD_*_SHORT field names have
-- shifted before across expansions. Versatility lists two candidates since tooltips only ever
-- show one "Versatility" stat but C_Item.GetItemStats may expose it under either name depending
-- on client version; first present key wins. Any stat whose key doesn't match here is simply
-- omitted from the readout rather than shown as a wrong/zero value.
local ITEM_STAT_KEYS = {
    haste       = { "ITEM_MOD_HASTE_RATING_SHORT" },
    crit        = { "ITEM_MOD_CRIT_RATING_SHORT" },
    mastery     = { "ITEM_MOD_MASTERY_RATING_SHORT" },
    versatility = { "ITEM_MOD_VERSATILITY", "ITEM_MOD_VERSATILITY_DAMAGE_DONE_SHORT" },
}

-- Maps a tooltip-scanned stat NAME (localized text, e.g. "Critical Strike") back to our internal
-- stat key — built lazily so it picks up L's real values rather than evaluating at file-load
-- order time.
local STAT_NAME_TO_KEY
local function StatKeyFromName(name)
    if not name then return nil end
    STAT_NAME_TO_KEY = STAT_NAME_TO_KEY or {
        [L.STAT_HASTE] = "haste", [L.STAT_CRIT] = "crit",
        [L.STAT_MASTERY] = "mastery", [L.STAT_VERSATILITY] = "versatility",
    }
    return STAT_NAME_TO_KEY[name]
end

-- One hidden scanning tooltip, reused for every enchant/item/gem lookup below rather than
-- touching the real GameTooltip — the standard technique for reading tooltip text off an addon.
local scanTip = CreateFrame("GameTooltip", "RecommendedStatsEnchantScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

-- Scans a real item's own tooltip for every "+<rating> <Stat Name>" line it displays — confirmed
-- live as the ONLY way to read a GEM's own granted stat: unlike normal equippable gear (which
-- C_Item.GetItemStats reads fine), a gem item apparently doesn't expose its rating through that
-- API at all, even though its tooltip shows the exact same "+rating stat" line format as
-- everything else. Used as ItemRatings' fallback below, so this only ever runs when the faster
-- API path came back empty. Starts from line 1 (unlike GetEnchantInfo's scan) since a plain item
-- link's line 1 is the item name, not a stat — no name to skip past here.
local function ScanItemTooltipRatings(itemLink)
    if not itemLink then return nil end
    scanTip:ClearLines()
    local ok = pcall(scanTip.SetHyperlink, scanTip, itemLink)
    if not ok then return nil end

    local out = {}
    for i = 1, scanTip:NumLines() do
        local line = _G["RecommendedStatsEnchantScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text then
            local r, s = text:match("^%+(%d+) (.+)$")
            local stat = r and StatKeyFromName(s)
            if stat then out[stat] = tonumber(r) end
        end
    end
    return next(out) and out or nil
end

-- {haste=rating, ...} for whichever secondary stats the item link actually rolls, or nil if
-- nothing matched via either path. Tries the fast API first (C_Item.GetItemStats — works for
-- normal gear) and falls back to a tooltip scan only if that comes back empty (needed for gems —
-- see ScanItemTooltipRatings above).
local function ItemRatings(itemLink)
    if not itemLink then return nil end
    local stats = C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)
    if stats then
        local out = {}
        for stat, keys in pairs(ITEM_STAT_KEYS) do
            for _, key in ipairs(keys) do
                local v = stats[key]
                if v and v > 0 then out[stat] = v; break end
            end
        end
        if next(out) then return out end
    end
    return ScanItemTooltipRatings(itemLink)
end

-- Player's own current (rating -> percent) conversion rate per stat, derived from their actual
-- equipped totals (GetCombatRating vs. the matching percent getter) rather than a hardcoded
-- formula — the real formula changes with level and has soft/hard caps, so "current percent per
-- current rating" is an ESTIMATE that holds well near the player's own stat level but can drift
-- at extreme values. Computed once per Render() pass, not per row. A stat is simply left out of
-- the returned table (not zero) when the player has none of it equipped, or its value is a
-- Secret this instant (Core.lua's issecretvalue — in an instance/combat) — callers fall back to
-- showing the plain rating with no percent rather than a wrong one.
local function RatingConversion()
    local conv = {}
    local specs = {
        haste       = { CR_HASTE_MELEE, GetHaste },
        crit        = { CR_CRIT_MELEE, GetCritChance },
        mastery     = { CR_MASTERY, GetMasteryEffect },
        versatility = { CR_VERSATILITY_DAMAGE_DONE, function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) end },
    }
    for stat, spec in pairs(specs) do
        local ratingType, pctFn = spec[1], spec[2]
        local rating = ratingType and GetCombatRating and GetCombatRating(ratingType)
        local pct = pctFn and pctFn()
        if rating and pct then
            -- Secrecy MUST be checked, and short-circuit, before `rating > 0` below — Lua's `and`
            -- evaluates left to right, so putting `not secret` after the comparison (as this
            -- originally did) still ran the comparison on a secret `rating` first and tainted the
            -- whole call. Confirmed live: GetCombatRating is secret-restricted in combat/instances
            -- just like the percent getters, not just presumed as this file originally guessed.
            local secret = issecretvalue and (issecretvalue(rating) or issecretvalue(pct))
            if not secret and rating > 0 then
                conv[stat] = pct / rating
            end
        end
    end
    return conv
end

local function FormatRating(stat, rating, conversion)
    local label = SHORT_STAT_LABEL[stat] or stat
    local rate = conversion[stat]
    if rate then
        return L.RATING_WITH_PCT:format(rating, label, rating * rate)
    end
    return L.RATING_NO_PCT:format(rating, label)
end

-- One formatted "+56 Haste (5.0%)" string per stat the table has, in STAT_ORDER — the item's own
-- stats render these one per line; an enchant/gem joins them onto its single line instead.
local function FormatRatingsList(ratingsTable, conversion)
    local parts = {}
    if not ratingsTable then return parts end
    for _, stat in ipairs(STAT_ORDER) do
        if ratingsTable[stat] then parts[#parts + 1] = FormatRating(stat, ratingsTable[stat], conversion) end
    end
    return parts
end

local function FormatRatingsLine(ratingsTable, conversion)
    local parts = FormatRatingsList(ratingsTable, conversion)
    if #parts == 0 then return nil end
    return table.concat(parts, "  ")
end

-- An enchant ISN'T an item, so there's no icon or standalone GetItemStats for it. The original
-- approach here read a dedicated "enchant:<id>" hyperlink's own tooltip — confirmed live NOT to
-- work (the enchant icon never showed at all), so this instead attaches the enchant to the
-- item's own itemString (item:<itemID>:<enchantID> — a minimal but valid link, same "item:"
-- hyperlink type already confirmed working for the item/gem rating readouts above, not a new
-- unverified one) and diffs its stats against the same item WITHOUT the enchant. Whatever
-- changed is exactly the enchant's own contribution, however many stats it touches — this
-- sidesteps needing to parse any enchant-specific tooltip line format at all. The enchant's own
-- display name still needs a tooltip line, but reads it off that same real "item:" link's
-- well-established "Enchanted: <Name>" convention, not a guess at unfamiliar hyperlink text.
local function BuildEnchantHostLink(itemID, enchantID)
    return ("item:%d:%d"):format(itemID, enchantID)
end

local function GetEnchantName(itemID, enchantID)
    scanTip:ClearLines()
    local ok = pcall(scanTip.SetHyperlink, scanTip, BuildEnchantHostLink(itemID, enchantID))
    if not ok then return nil end
    for i = 1, scanTip:NumLines() do
        local line = _G["RecommendedStatsEnchantScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        local name = text and text:match("^Enchanted: (.+)$")
        if name then return name end
    end
    return nil
end

local enchantInfoCache = {}
local function GetEnchantInfo(itemID, enchantID)
    if enchantInfoCache[enchantID] ~= nil then return enchantInfoCache[enchantID] or nil end

    local withEnchant = ItemRatings(BuildEnchantHostLink(itemID, enchantID))
    local base = ItemRatings(("item:%d"):format(itemID))
    local ratings
    if withEnchant then
        local diff = {}
        for stat, v in pairs(withEnchant) do
            local d = v - ((base and base[stat]) or 0)
            if d > 0 then diff[stat] = d end
        end
        if next(diff) then ratings = diff end
    end

    local name = GetEnchantName(itemID, enchantID)
    if not name and not ratings then
        enchantInfoCache[enchantID] = false
        return nil
    end

    local info = { name = name, ratings = ratings }
    enchantInfoCache[enchantID] = info
    return info
end

--------------------------------------------------------------------------------
-- Build one slot row
--
--   [icon]  * Head                                        NEW  90%
--   [    ]  Abyssal Doomhound's Relentless Stare
--           +135 Crit (6.1%)          [e] +38 Mastery (1.3%)
--           +66 Mastery (2.3%)        [g] +54 Crit (1.2%)
--------------------------------------------------------------------------------

-- One enchant/gem line in the mods sub-column: icon + its own rating text, hoverable as a whole
-- line (a bigger target than the icon alone) for the enchant/gem name.
local function CreateModLine(row, index)
    local line = CreateFrame("Button", nil, row)
    line:SetSize(COL_W - MODS_X, LINE_H)
    line:SetPoint("TOPLEFT", MODS_X, STATS_Y - (index - 1) * (LINE_H + 2))

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(LINE_H, LINE_H)
    line.icon:SetPoint("LEFT", 0, 0)
    line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    line.text = line:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
    line.text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)

    line:SetScript("OnEnter", function(self)
        if not self.tooltipName then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipName, 1, 1, 1)
        if self.tooltipRatingText then GameTooltip:AddLine(self.tooltipRatingText, 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
    line:Hide()
    return line
end

local function CreateRow(parent, tooltipAnchor)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(COL_W, ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    row.tooltipAnchor = tooltipAnchor

    -- Faint band per row so the stacked lines read as one item, not a loose text column.
    local bg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.025)

    -- quality-tinted ring behind the icon (colored via item:GetItemQuality() once it loads) —
    -- slightly larger than the icon so it reads as a border, not a background fill
    row.iconBorder = row:CreateTexture(nil, "BACKGROUND")
    row.iconBorder:SetSize(ICON_SZ + 2, ICON_SZ + 2)
    row.iconBorder:SetPoint("TOPLEFT", 4, -4)
    row.iconBorder:SetColorTexture(1, 1, 1, 0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SZ, ICON_SZ)
    row.icon:SetPoint("CENTER", row.iconBorder, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Green/yellow/red equipped-vs-BiS status dot — see SLOT_TO_INVSLOT/DOT_TEXTURE above.
    row.statusDot = row:CreateTexture(nil, "OVERLAY")
    row.statusDot:SetSize(8, 8)
    row.statusDot:SetPoint("TOPLEFT", TEXT_X + 4, -5)

    row.slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.slotLabel:SetPoint("LEFT", row.statusDot, "RIGHT", 5, 0)
    row.slotLabel:SetJustifyH("LEFT")

    row.pct = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.pct:SetPoint("TOPRIGHT", -6, -4)
    row.pct:SetWidth(40)
    row.pct:SetJustifyH("RIGHT")

    -- Short-lived tag for a slot whose #1 pick changed recently (entry.changedAt) — see
    -- NEW_TAG_DAYS above.
    row.newTag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.newTag:SetPoint("RIGHT", row.pct, "LEFT", -6, 0)
    row.newTag:SetText(L.NEW_TAG)
    row.newTag:SetTextColor(unpack(GOLD))
    row.newTag:Hide()

    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.itemName:SetPoint("TOPLEFT", TEXT_X + 4, -16)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)

    -- The item's OWN secondary-stat ratings, one per line ("+56 Haste (5.0%)" / "+56 Vers (5.0%)").
    row.statLines = {}
    for i = 1, MAX_STAT_LINES do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", TEXT_X + 4, STATS_Y - (i - 1) * LINE_H)
        fs:SetWidth(MODS_X - TEXT_X - 12)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetTextColor(unpack(STAT_TEXT_COLOR))
        row.statLines[i] = fs
    end

    -- Enchant/gem lines — purely informational (what's recommended + what it grants), not a
    -- comparison against the player's own equipped enchant/gem; the ilvl-aware status dot already
    -- covers "do you have an appropriate item here" at the whole-item level. Filled in order, so a
    -- slot with only a gem shows it on the first line rather than leaving a hole above it.
    row.modLines = { CreateModLine(row, 1), CreateModLine(row, 2) }

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)
    row:SetHighlightTexture(highlight)

    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, self.tooltipAnchor)
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
-- Row content
--------------------------------------------------------------------------------

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

local function SetStatLines(row, list)
    for i, fs in ipairs(row.statLines) do
        local text = list and list[i]
        fs:SetText(text or "")
        fs:SetShown(text ~= nil)
    end
end

local function SetRowItem(row, slot, entry, conversion)
    -- Item/gem data arrives asynchronously (ContinueOnItemLoad), and this window re-renders on
    -- every equipment/rating/spec/content change — a callback from an earlier render must not
    -- paint its (possibly different) item over what this render put in the row.
    row.renderToken = (row.renderToken or 0) + 1
    local token = row.renderToken

    local itemID, pct = entry.itemID, entry.pct
    row.itemID = itemID
    row.itemLink = BuildItemLink(itemID, entry.bonusIDs)
    row.decoratedLink = nil -- filled in once the async item load below resolves
    row.pct:SetText(pct and (pct .. "%") or "")
    if pct and pct >= PCT_HIGH_THRESHOLD then
        row.pct:SetTextColor(unpack(PCT_HIGH_COLOR))
    else
        row.pct:SetTextColor(unpack(DIM))
    end
    row.itemName:SetText("...")
    row.itemName:SetTextColor(1, 1, 1)
    row.icon:SetTexture(QUESTION_MARK_ICON)
    row.iconBorder:SetColorTexture(1, 1, 1, 0.25)
    row.slotLabel:SetText(SLOT_LABEL[slot] or slot)
    -- Hidden until the item load below resolves, so it never shows a stale value from a previous
    -- key/spec this row was last rendered for.
    SetStatLines(row, nil)

    -- Status dot: green for the exact #1 pick. Yellow covers the runner-up (entry.altItemID) OR
    -- the player's own item being at least as strong by ilvl (entry.ilvl, aggregate.js) even
    -- though it's a different itemID. Red is neither.
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

    -- Enchant/gem lines, filled in order (enchant first). An enchant's info comes from
    -- GetEnchantInfo's item-link diff (see its own header comment), so it's available right away;
    -- a gem's rating only once its item data has loaded (calling C_Item.GetItemStats before that
    -- returned nothing for most items).
    local nextMod = 1
    local enchantInfo = entry.enchantID and GetEnchantInfo(itemID, entry.enchantID)
    if enchantInfo then
        local line = row.modLines[nextMod]
        nextMod = nextMod + 1
        local ratingText = FormatRatingsLine(enchantInfo.ratings, conversion)
        line.icon:SetTexture(ENCHANT_ICON)
        -- Falls back to the generic label rather than leaving this nil: if only the ratings-diff
        -- half resolved (or vice versa), the tooltip should still show whatever it has.
        line.tooltipName = enchantInfo.name or L.BIS_ENCHANT_LABEL
        line.tooltipRatingText = ratingText
        line.text:SetText(ratingText or line.tooltipName)
        line:Show()
    end

    if entry.gemID then
        local line = row.modLines[nextMod]
        nextMod = nextMod + 1
        line.icon:SetTexture(QUESTION_MARK_ICON)
        line.tooltipName, line.tooltipRatingText = nil, nil
        line.text:SetText("")
        line:Show()
        local gemLink = "item:" .. entry.gemID
        local gemItem = Item:CreateFromItemID(entry.gemID)
        gemItem:ContinueOnItemLoad(function()
            if row.renderToken ~= token then return end
            local ratingText = FormatRatingsLine(ItemRatings(gemLink), conversion)
            line.icon:SetTexture(gemItem:GetItemIcon())
            line.tooltipName = gemItem:GetItemName() or L.BIS_GEM_LABEL
            line.tooltipRatingText = ratingText
            line.text:SetText(ratingText or line.tooltipName)
        end)
    end

    for i = nextMod, #row.modLines do
        local line = row.modLines[i]
        line.tooltipName, line.tooltipRatingText = nil, nil
        line:Hide()
    end

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

    local itemLinkForStats = row.itemLink or ("item:" .. itemID)
    local item = row.itemLink and Item:CreateFromItemLink(row.itemLink) or Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        if row.renderToken ~= token then return end
        local name = item:GetItemName() or ("Item " .. itemID)
        local quality = item:GetItemQuality()
        row.itemName:SetText(name)
        row.decoratedLink = BuildDecoratedLink(row.itemLink or ("item:" .. itemID), name, quality)
        row.icon:SetTexture(item:GetItemIcon())
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then
            row.iconBorder:SetColorTexture(r, g, b, 0.9)
            row.itemName:SetTextColor(r, g, b)
        end

        -- The item's OWN secondary-stat ratings — a bare "item:<id>" link (when entry.bonusIDs
        -- is empty, BuildItemLink's fallback) reads the item's base-template stats rather than a
        -- specific drop's real roll, the same base-template caveat BuildItemLink's own comment
        -- documents — still real numbers, just not necessarily this exact drop's exact roll.
        SetStatLines(row, FormatRatingsList(ItemRatings(itemLinkForStats), conversion))
    end)
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local frame, titleText, subLabel, tierLine, emptyText
local toggleBtns, rows = {}, {}

local function ShowEmpty(msg)
    for _, row in ipairs(rows) do row:Hide() end
    subLabel:SetText("")
    tierLine:Hide()
    emptyText:SetText(msg)
    emptyText:Show()
end

local function SpecName()
    local idx = GetSpecialization and GetSpecialization()
    return idx and select(2, GetSpecializationInfo(idx)) or ""
end

local function Render()
    -- Recomputed stats/gear (login, gear change, rating update) must not force the window into
    -- existence or redraw it while closed — OnShow renders fresh anyway.
    if not (frame and frame:IsShown()) then return end

    titleText:SetText(L.BIS_WINDOW_TITLE:format(SpecName()))

    local content = RS:GetContent()
    local accent = RS:GetAccentColor()
    for _, btn in ipairs(toggleBtns) do
        local active = btn.value == content
        local hasData = RS:HasDataFor(btn.value)
        btn:SetEnabled(active or hasData)
        btn.bg:SetColorTexture(unpack(active and TAB_ACTIVE_BG or TAB_IDLE_BG))
        local c = active and accent or DIM
        btn.label:SetTextColor(c[1], c[2], c[3], (active or hasData) and 1 or 0.4)
    end

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
    -- aggregate.js's `100 * bestN / top.length`) — RS:GetSampleSizeFor falls back to the target
    -- when the per-key count isn't available (older data, or a placeholder SampleSize.lua) so the
    -- label never goes blank.
    local m = RecommendedStatsData_Meta
    local n = RS:GetSampleSizeFor(key) or (m and m.sampleSize) or 0
    local difficulty = RecommendedStatsData_RaidDifficulty and RecommendedStatsData_RaidDifficulty[key]
    local fallbackLabel = difficulty and DIFFICULTY_LABEL[difficulty]
    if fallbackLabel then
        subLabel:SetFormattedText(L.BIS_PCT_FALLBACK, n, fallbackLabel)
        subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    elseif RS:IsSampleSizeLow(key) then
        subLabel:SetFormattedText(L.BIS_PCT_LOW_SAMPLE, n)
        subLabel:SetTextColor(unpack(FALLBACK_COLOR))
    else
        subLabel:SetFormattedText(L.BIS_PCT_PLAIN, n)
        subLabel:SetTextColor(unpack(DIM))
    end

    -- Tier-set 2pc/4pc line. Hidden when RecommendedStatsData_TierSet has nothing for this key
    -- (config.tierSetItemIDs not yet populated for this class, see RecommendedStatsNode/config.js).
    local tierData = RecommendedStatsData_TierSet and RecommendedStatsData_TierSet[key]
    if tierData and tierData.itemIDs and #tierData.itemIDs > 0 then
        local owned = CountEquippedTierPieces(tierData.itemIDs)
        tierLine:SetFormattedText(L.BIS_TIER_LINE, owned, tierData.pct4pc or 0)
        tierLine:Show()
    else
        tierLine:Hide()
    end

    emptyText:Hide()
    -- Computed once per pass, not per row — see RatingConversion's own comment for why this is
    -- an estimate derived from the player's current equipped totals.
    local conversion = RatingConversion()
    for i, slot in ipairs(SLOT_ORDER) do
        local row = rows[i]
        local entry = bis[slot]
        if not entry then
            row:Hide()
        else
            row:Show()
            SetRowItem(row, slot, entry, conversion)
        end
    end
end

table.insert(RS.listeners, Render)

local function EnsureWindow()
    if frame then return end

    frame = CreateFrame("Frame", "RecommendedStatsBiS", UIParent, "BackdropTemplate")
    frame:SetSize(WIN_W, WIN_H)
    -- Same strata/toplevel setup as UI/TalentsWindow.lua: above the character sheet, below
    -- Blizzard's dropdown menus, raised to the front whenever it's opened or clicked.
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    StyleBackdrop(frame)
    RS:MakeMovable(frame, "bisPos", function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end)
    tinsert(UISpecialFrames, "RecommendedStatsBiS")

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", PAD, -14)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("RIGHT", close, "LEFT", -6, 0)
    hint:SetText(L.BIS_WINDOW_HINT)

    -- Controls row: Raid / Mythic+ toggle (shared setting, see header comment), tier line, and
    -- the "% of top N" label over the right-hand % column.
    local toggleW = 96
    for i, choice in ipairs(CONTENT_CHOICES) do
        local btn = CreateFrame("Button", nil, frame)
        btn.value = choice.value
        btn:SetSize(toggleW, 24)
        btn:SetPoint("TOPLEFT", PAD + (i - 1) * (toggleW + 4), CONTROLS_Y)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.label:SetPoint("CENTER")
        btn.label:SetText(choice.text)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        btn:SetScript("OnClick", function(self)
            -- RS:SetContent refreshes every listener, this window's Render included.
            if RS:GetContent() ~= self.value then RS:SetContent(self.value) end
        end)
        toggleBtns[i] = btn
    end

    tierLine = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tierLine:SetPoint("LEFT", toggleBtns[#toggleBtns], "RIGHT", 16, 0)
    tierLine:SetTextColor(unpack(DIM))
    tierLine:Hide()

    subLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subLabel:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD - 6, -HEADER_H + 6)

    -- Thin divider between the two columns.
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.06)
    divider:SetWidth(1)
    divider:SetPoint("TOP", frame, "TOPLEFT", PAD + COL_W + COL_GAP / 2, -HEADER_H)
    divider:SetPoint("BOTTOM", frame, "BOTTOMLEFT", PAD + COL_W + COL_GAP / 2, PAD)

    for i in ipairs(SLOT_ORDER) do
        local col = (i <= ROWS_PER_COL) and 0 or 1
        local r = (i - 1) % ROWS_PER_COL
        -- Left column's tooltips open to the left, right column's to the right, so a tooltip
        -- never covers the other column.
        local row = CreateRow(frame, col == 0 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        row:SetPoint("TOPLEFT", PAD + col * (COL_W + COL_GAP), -HEADER_H - r * (ROW_H + ROW_GAP))
        rows[i] = row
    end

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, -HEADER_H / 2)
    emptyText:SetWidth(WIN_W - 80)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()

    frame:SetScript("OnShow", function(self)
        self:Raise()
        -- Re-snapped every open, so a UI scale change since the last one can't drop an edge again.
        StyleBackdrop(self)
        Render()
    end)

    -- CreateFrame returns a SHOWN frame — hide it so the first RS:ToggleBiS() call opens it
    -- instead of seeing IsShown() == true and closing it (same fix as UI/TalentsWindow.lua).
    frame:Hide()
end

function RS:ToggleBiS()
    EnsureWindow()
    frame:SetShown(not frame:IsShown())
end

-- Options' "Show BiS" turned off: the launcher button disappears (UI/CharacterPanel.lua), so an
-- already-open window goes with it rather than lingering with no way back to it.
table.insert(RS.visibilitySyncers, function()
    if frame and not RS:GetShowBiS() then frame:Hide() end
end)

table.insert(RS.skinListeners, function()
    if frame then
        StyleBackdrop(frame)
        Render()
    end
end)
