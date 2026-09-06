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
local PANEL_W    = 440 -- must match CharacterPanel.lua's PANEL_W (RS.bisPage spans the full window width)
-- 32, not the original 22 — leaves room for a second line under both the item name (its own
-- rating readout, row.subLine) and the enchant/gem icon block (their own rating readout,
-- row.gearModsRating) — see CreateRow/SetRowItem below. CharacterPanel.lua no longer hand-syncs
-- a duplicate constant for this — see RS:GetBisContentHeight() below, which computes it from
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

-- Rating readouts (item's own stats, and what a recommended enchant/gem itself grants) — this
-- file owns its own copy of these rather than importing CharacterPanel.lua's, same "each file
-- owns its own layout locals independently" convention as PANEL_W above.
local STAT_ORDER = { "haste", "crit", "mastery", "versatility" }
local SHORT_STAT_LABEL = {
    haste = L.STAT_HASTE_SHORT, crit = L.STAT_CRIT_SHORT, mastery = L.STAT_MASTERY_SHORT, versatility = L.STAT_VERSATILITY_SHORT,
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

local function FormatRatingsLine(ratingsTable, conversion)
    if not ratingsTable then return nil end
    local parts = {}
    for _, stat in ipairs(STAT_ORDER) do
        if ratingsTable[stat] then parts[#parts + 1] = FormatRating(stat, ratingsTable[stat], conversion) end
    end
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

    -- Enchant/gem icon block — sits between the slot label and the item itself. Purely
    -- informational (what's recommended + what it grants), not a comparison against the player's
    -- own equipped enchant/gem — the ilvl-aware status dot already covers "do you have an
    -- appropriate item here" at the whole-item level. A gem is a real WoW item, so its icon/name
    -- come straight off it (SetRowItem below); an enchant isn't, so it gets a fixed generic icon
    -- and its name comes from GetEnchantInfo's tooltip scan instead.
    -- 13, not 14: the icon-block rating line below needs every spare pixel of vertical room it
    -- can get within ROW_H (an icon is taller than a line of text, so this stack is tighter than
    -- the item name/rating stack on the right even at the same row height).
    local ICON_SZ = 13
    row.gearMods = CreateFrame("Frame", nil, row)
    row.gearMods:SetSize(44, ROW_H)
    row.gearMods:SetPoint("TOPLEFT", row.slotLabel, "TOPRIGHT", 4, 0)

    row.enchantIcon = CreateFrame("Button", nil, row.gearMods)
    row.enchantIcon:SetSize(ICON_SZ, ICON_SZ)
    row.enchantIcon:SetPoint("TOPLEFT", row.gearMods, "TOPLEFT", 0, 6)
    row.enchantIcon.tex = row.enchantIcon:CreateTexture(nil, "ARTWORK")
    row.enchantIcon.tex:SetAllPoints()
    row.enchantIcon:Hide()

    row.gemIcon = CreateFrame("Button", nil, row.gearMods)
    row.gemIcon:SetSize(ICON_SZ, ICON_SZ)
    row.gemIcon:SetPoint("LEFT", row.enchantIcon, "RIGHT", 2, 0)
    row.gemIcon.tex = row.gemIcon:CreateTexture(nil, "ARTWORK")
    row.gemIcon.tex:SetAllPoints()
    row.gemIcon:Hide()

    for _, iconBtn in ipairs({ row.enchantIcon, row.gemIcon }) do
        iconBtn:SetScript("OnEnter", function(self)
            if not self.tooltipName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipName, 1, 1, 1)
            if self.tooltipRatingText then GameTooltip:AddLine(self.tooltipRatingText, 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end)
        iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- What the enchant/gem itself grants, e.g. "+56 Haste (5.0%)  +23 Vers (2.0%)".
    row.gearModsRating = row.gearMods:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.gearModsRating:SetPoint("TOPLEFT", row.enchantIcon, "BOTTOMLEFT", 0, -1)
    row.gearModsRating:SetJustifyH("LEFT")

    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- TOPRIGHT, not TOP: "TOP" anchors to a frame's horizontal CENTER, not its right edge — that
    -- put itemName's left edge overlapping the previous element instead of starting after it.
    -- Confirmed live once already (against slotLabel); same rule applies here against gearMods.
    row.itemName:SetPoint("TOPLEFT", row.gearMods, "TOPRIGHT", 4, 6)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)

    -- The item's OWN secondary-stat rating(s), e.g. "+56 Haste (5.0%)  +56 Vers (5.0%)" — this
    -- used to be the enchant/gem match indicator, which moved to the icon block above.
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

local function SetRowItem(row, slot, entry, conversion)
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

    -- Enchant/gem icon block — icon + name/rating-on-hover, informational (see the block's own
    -- header comment in CreateRow for why this doesn't compare against the player's own gear).
    -- The rating line below the icons is rebuilt from whichever of enchantPart/gemPart have
    -- resolved so far, since the gem's half only arrives once its item data finishes loading
    -- (see the ContinueOnItemLoad below — calling C_Item.GetItemStats before an item is
    -- confirmed loaded returned nothing for most items, the same reason icon/name already wait
    -- for this elsewhere in this function; the fix here is applying that same wait to ratings).
    local enchantPart, gemPart
    local function RefreshGearModsRating()
        local parts = {}
        if enchantPart then parts[#parts + 1] = enchantPart end
        if gemPart then parts[#parts + 1] = gemPart end
        row.gearModsRating:SetText(table.concat(parts, "  "))
    end

    if entry.gemID then
        local gemLink = "item:" .. entry.gemID
        local gemItem = Item:CreateFromItemID(entry.gemID)
        row.gemIcon:Show()
        row.gemIcon.tex:SetTexture(QUESTION_MARK_ICON)
        row.gemIcon.tooltipName, row.gemIcon.tooltipRatingText = nil, nil
        gemItem:ContinueOnItemLoad(function()
            row.gemIcon.tex:SetTexture(gemItem:GetItemIcon())
            row.gemIcon.tooltipName = gemItem:GetItemName()
            gemPart = FormatRatingsLine(ItemRatings(gemLink), conversion)
            row.gemIcon.tooltipRatingText = gemPart
            RefreshGearModsRating()
        end)
    else
        row.gemIcon:Hide()
        row.gemIcon.tooltipName, row.gemIcon.tooltipRatingText = nil, nil
    end

    -- Unlike the gem, an enchant's info comes from GetEnchantInfo's item-link diff (see its own
    -- header comment), not an item load, so it's already available synchronously here — no
    -- waiting needed for this half.
    local enchantInfo = entry.enchantID and GetEnchantInfo(itemID, entry.enchantID)
    if enchantInfo then
        row.enchantIcon:Show()
        row.enchantIcon.tex:SetTexture("Interface\\Icons\\INV_Enchant_Disenchant")
        -- Falls back to the generic label rather than leaving this nil: if only the ratings-diff
        -- half resolved (or vice versa), the tooltip should still show whatever it has instead
        -- of not showing at all (the OnEnter handler bails out entirely when tooltipName is nil).
        row.enchantIcon.tooltipName = enchantInfo.name or L.BIS_ENCHANT_LABEL
        enchantPart = FormatRatingsLine(enchantInfo.ratings, conversion)
        row.enchantIcon.tooltipRatingText = enchantPart
    else
        row.enchantIcon:Hide()
        row.enchantIcon.tooltipName, row.enchantIcon.tooltipRatingText = nil, nil
    end
    RefreshGearModsRating() -- shows the enchant half immediately; the gem half (if any) fills in above once loaded

    -- The item's OWN secondary-stat rating(s) is populated inside item:ContinueOnItemLoad below,
    -- same reasoning as the gem above — hidden until then so it never shows a stale value from a
    -- previous key/spec this row was last rendered for.
    row.subLine:Hide()

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
        local name = item:GetItemName() or ("Item " .. itemID)
        local quality = item:GetItemQuality()
        row.itemName:SetText(name)
        row.decoratedLink = BuildDecoratedLink(row.itemLink or ("item:" .. itemID), name, quality)
        row.icon:SetTexture(item:GetItemIcon())
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then row.iconBorder:SetColorTexture(r, g, b, 0.9) end

        -- The item's OWN secondary-stat rating(s) — a bare "item:<id>" link (when entry.bonusIDs
        -- is empty, BuildItemLink's fallback) reads the item's base-template stats rather than a
        -- specific drop's real roll, the same base-template caveat BuildItemLink's own comment
        -- documents — still real numbers, just not necessarily this exact drop's exact roll.
        local ratingsLine = FormatRatingsLine(ItemRatings(itemLinkForStats), conversion)
        row.subLine:SetShown(ratingsLine ~= nil)
        if ratingsLine then row.subLine:SetText(ratingsLine) end
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
            row.slotLabel:SetText(SLOT_LABEL[slot] or slot)
            SetRowItem(row, slot, entry, conversion)
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
