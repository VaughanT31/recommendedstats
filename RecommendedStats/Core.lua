local ADDON = ...
RecommendedStats = RecommendedStats or {}
local RS = RecommendedStats
local L = RecommendedStats_Locale
local EXPECTED_SCHEMA = 1

-- ⚠ VERIFY these return PERCENT (not rating) on live 12.1 before shipping (see scope.md §11).
-- Reverted 2026-09-09: swapping these to GetCombatRatingBonus (to match RecommendedStatsNode's
-- itemization-only rating_bonus targets) was based on the assumption that GetCombatRatingBonus
-- returns a clean itemization-only percent. A live /dump of GetCombatRatingBonus(CR_VERSATILITY_
-- DAMAGE_DONE) — untouched by that change, and supposedly the one stat with zero passive component
-- per bnet.js's extractStats comment — came back 2.31%, while the character sheet showed 8.31% for
-- the same character at the same moment. That gap disproves the "GetCombatRatingBonus == total for
-- a passive-free stat" premise the swap relied on, so it isn't safe to assume for haste/crit/mastery
-- either. Back to the total-percent getters, which is what actually matches the character sheet.
-- The real itemization-vs-total mismatch against RecommendedStatsNode's targets is still open —
-- next step is fixing it on the Node side (aggregate.js targets built from `.value` instead of
-- `.rating_bonus`, since each StatTargets key is already scoped to one class+spec) rather than here.
local function ReadStats()
    return {
        haste       = GetHaste(),
        crit        = GetCritChance(),        -- casters: GetSpellCritChance()
        mastery     = GetMasteryEffect(),
        versatility = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE),
    }
end

-- Raw combat rating alongside the percent above — gear/enchants/gems are itemized in rating, not
-- percent (see UI/BiSWindow.lua's own rating readouts), so the stat panel shows both. Same
-- CR_HASTE_MELEE/CR_CRIT_MELEE constants BiSWindow.lua already uses for its own rating-to-percent
-- conversion estimate — melee/ranged/spell combat ratings are the same underlying gear stat, this
-- just reads whichever one happens to share a name with the unified percent getters above.
local RATING_TYPE = {
    haste = CR_HASTE_MELEE, crit = CR_CRIT_MELEE, mastery = CR_MASTERY, versatility = CR_VERSATILITY_DAMAGE_DONE,
}
local function ReadRatings()
    local out = {}
    for stat, ratingType in pairs(RATING_TYPE) do
        out[stat] = GetCombatRating and ratingType and GetCombatRating(ratingType)
    end
    return out
end

local function GetClassToken() local _, c = UnitClass("player"); return c end

local SPEC_TOKENS = {
    [71]  = "ARMS",           [72]  = "FURY",         [73]   = "PROTECTION",      -- Warrior
    [65]  = "HOLY",           [66]  = "PROTECTION",   [70]   = "RETRIBUTION",     -- Paladin
    [253] = "BEASTMASTERY",   [254] = "MARKSMANSHIP", [255]  = "SURVIVAL",        -- Hunter
    [259] = "ASSASSINATION",  [260] = "OUTLAW",       [261]  = "SUBTLETY",        -- Rogue
    [256] = "DISCIPLINE",     [257] = "HOLY",         [258]  = "SHADOW",          -- Priest
    [250] = "BLOOD",          [251] = "FROST",        [252]  = "UNHOLY",          -- Death Knight
    [262] = "ELEMENTAL",      [263] = "ENHANCEMENT",  [264]  = "RESTORATION",     -- Shaman
    [62]  = "ARCANE",         [63]  = "FIRE",         [64]   = "FROST",           -- Mage
    [265] = "AFFLICTION",     [266] = "DEMONOLOGY",   [267]  = "DESTRUCTION",     -- Warlock
    [268] = "BREWMASTER",     [269] = "WINDWALKER",   [270]  = "MISTWEAVER",      -- Monk
    [102] = "BALANCE",        [103] = "FERAL",        [104]  = "GUARDIAN",   [105] = "RESTORATION", -- Druid
    [577] = "HAVOC",          [581] = "VENGEANCE",    [1480] = "DEVOURER",       -- Demon Hunter
    [1467] = "DEVASTATION",   [1468] = "PRESERVATION", [1473] = "AUGMENTATION",   -- Evoker
}
local function GetSpecToken()
    local idx = GetSpecialization(); if not idx then return nil end
    return SPEC_TOKENS[(GetSpecializationInfo(idx))]
end

function RS:GetContent()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.content or "RAID"
end
function RS:SetContent(c)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.content = c
    RS:Refresh()
    print(L.CHAT_PREFIX .. L.MSG_CONTENT_SET:format(c))
end

--------------------------------------------------------------------------------
-- Options (attach mode, section toggles) — read by UI/OptionsPanel.lua and the
-- minimap button, applied by UI/CharacterPanel.lua and UI/BiSWindow.lua.
--------------------------------------------------------------------------------
function RS:GetAttachMode()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.attachMode or "ATTACHED"
end
function RS:SetAttachMode(mode)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.attachMode = mode
    RS:SyncVisibility()
end

function RS:GetShowBiS()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.showBiS ~= false
end
function RS:SetShowBiS(shown)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.showBiS = shown
    RS:SyncVisibility()
end

-- Independent of showBiS above — lets a player who only wants the BiS gear list (or vice versa)
-- turn off the other section without losing panel position/attach-mode state.
function RS:GetShowStats()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.showStats ~= false
end
function RS:SetShowStats(shown)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.showStats = shown
    RS:SyncVisibility()
end

-- Row density for the "Recommended Stats" tab — DEFAULT (name/value/bar, current look),
-- SMALL (one line, no bar), MEDIUM (one line + bar), LARGE (DEFAULT plus a delta-from-target
-- line). Read/applied by UI/CharacterPanel.lua via RS.statsSizeListeners, mirroring the
-- RS.skinListeners pattern below since this file doesn't know what UI (if any) exists yet.
function RS:GetStatsSize()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.statsSize or "DEFAULT"
end

RS.statsSizeListeners = {}
function RS:SetStatsSize(size)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.statsSize = size
    for _, fn in ipairs(RS.statsSizeListeners) do fn() end
end

-- Minimap icon itself (distinct from the panels it toggles) — read by UI/MinimapButton.lua.
-- Adds a shape/icon cue alongside the existing red/green/blue state colors (under/on/over/secret
-- in the stat panel, bis/alt/missing in the BiS dot) — those states are color-only today, which
-- is a real gap for colorblind players. Read by UI/CharacterPanel.lua and UI/BiSWindow.lua,
-- toggled from UI/OptionsPanel.lua, same accessor pattern as RS:GetShowBiS()/RS:SetShowBiS().
function RS:GetColorblindMode()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.colorblindMode == true
end
function RS:SetColorblindMode(enabled)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.colorblindMode = enabled
    RS:Refresh()
    RS:SyncTabs()
end

function RS:GetShowMinimapIcon()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.showMinimapIcon ~= false
end
function RS:SetShowMinimapIcon(shown)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.showMinimapIcon = shown
    if RS.minimapButton then RS.minimapButton:SetShown(shown) end
end

--------------------------------------------------------------------------------
-- Skins — an accent color applied to chrome only (active tab text, target tick,
-- panel border, minimap ring). Deliberately never touches the stat bar/status
-- colors in Evaluate()'s state (under/on/over/secret) below — those stay
-- semantic red/green/blue so the at-a-glance verdict can't get muddied by a
-- color scheme. Read by UI/OptionsPanel.lua (the picker) and applied via
-- RS.skinListeners by UI/CharacterPanel.lua and UI/MinimapButton.lua.
--------------------------------------------------------------------------------
local DEFAULT_ACCENT = { 1, 0.82, 0.15 } -- this addon's original gold tab-accent, unchanged

-- C_ClassColor is the modern (post-Dragonflight) API; RAID_CLASS_COLORS still exists as a
-- fallback in case a future client removes it, same defensive spirit as RS:GetAccentColor()
-- below falling back to gold rather than erroring the whole UI over a cosmetic.
local function GetClassColor()
    local class = GetClassToken()
    if not class then return nil end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local c = C_ClassColor.GetClassColor(class)
        if c then return { c.r, c.g, c.b } end
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return nil
end

function RS:GetSkin()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.skin or "DEFAULT"
end

function RS:GetCustomColor()
    RecommendedStatsDB = RecommendedStatsDB or {}
    local c = RecommendedStatsDB.customColor
    return c and { c[1], c[2], c[3] } or { 1, 1, 1 }
end

function RS:SetCustomColor(r, g, b)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.customColor = { r, g, b }
    RS:ApplySkin()
end

function RS:GetAccentColor()
    local skin = RS:GetSkin()
    if skin == "CLASS" then
        return GetClassColor() or DEFAULT_ACCENT
    elseif skin == "CUSTOM" then
        return RS:GetCustomColor()
    end
    return DEFAULT_ACCENT
end

function RS:SetSkin(skin)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.skin = skin
    RS:ApplySkin()
end

-- One "re-tint my already-built chrome" closure per registrant — mirrors RS.listeners/
-- RS.tabSyncers so this file doesn't need to know what UI exists (or has even been built
-- yet) when a skin change fires.
RS.skinListeners = {}
function RS:ApplySkin()
    local accent = RS:GetAccentColor()
    for _, fn in ipairs(RS.skinListeners) do fn(accent) end
end

--------------------------------------------------------------------------------
-- "New data available" chat ping — separate from the stale-data footer warning.
-- Fires once per new Meta.updated date (not every login) so players notice a fresh
-- twice-weekly data rebuild landed even if they never open the panel. Distinct from
-- UI/WhatsNew.lua's popup, which is for actual feature releases, not routine data
-- refreshes — this is the routine-refresh half of that same "keep players informed"
-- idea.
--------------------------------------------------------------------------------
function RS:GetLastSeenDataUpdate()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.lastSeenDataUpdate
end

function RS:AnnounceDataUpdateIfNew()
    local m = RecommendedStatsData_Meta
    local updated = m and m.updated
    if not updated or updated == RS:GetLastSeenDataUpdate() then return end

    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.lastSeenDataUpdate = updated
    print(L.CHAT_PREFIX .. L.MSG_DATA_REFRESHED:format(
        updated, m.sampleSize or 0, m.gamePatch or "?"
    ))
end

function RS:GetKey()
    local class, spec = GetClassToken(), GetSpecToken()
    if not (class and spec) then return nil end
    return class .. "_" .. spec .. "_" .. RS:GetContent()
end

function RS:SchemaOK()
    local m = RecommendedStatsData_Meta
    return m and m.schema == EXPECTED_SCHEMA
end

-- Used by the Raid/Mythic+ dropdown (UI/CharacterPanel.lua) to grey out a choice this class/spec
-- has nothing real for, rather than letting the player pick a dead end that shows "no data" on
-- both tabs. Requires BOTH stat targets AND BiS gear picks — a spec can get real stat targets
-- from as few as one verified player (aggregate.js just needs a numeric value), so targets alone
-- existing isn't a meaningful signal on its own; BiS needing at least one populated slot is what
-- actually distinguishes "this build found real raid data for this spec" (see UI/BiSWindow.lua's
-- Render(), which treats a present-but-empty BiS table the same as no data at all).
function RS:HasDataFor(content)
    local class, spec = GetClassToken(), GetSpecToken()
    if not (class and spec) then return true end -- unknown yet — don't block on a guess
    local key = class .. "_" .. spec .. "_" .. content
    local hasTargets = RecommendedStatsData_Targets and RecommendedStatsData_Targets[key] ~= nil
    local bis = RecommendedStatsData_BiS and RecommendedStatsData_BiS[key]
    local hasBis = bis and next(bis) ~= nil
    return hasTargets and hasBis
end

-- Shared by the stale-data footer warning (UI/CharacterPanel.lua) and the BiS "NEW" tag
-- (UI/BiSWindow.lua) — both just need "how many days old is this YYYY-MM-DD date", parsed via
-- os.date/time rather than string comparison so a build that runs slightly late in UTC vs. the
-- player's local date doesn't misfire. Returns nil (never "stale"/"new") if the string is missing
-- or malformed rather than erroring, since Data/Meta.lua's shape is only as reliable as whatever
-- Node build produced it.
function RS:DaysSince(dateStr)
    if not dateStr then return nil end
    local y, mo, d = dateStr:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    local stamp = time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 })
    return math.floor((time() - stamp) / 86400)
end

-- A build pipeline outage (season transition, expired API credentials, etc.) means players keep
-- getting served stat targets from before whatever changed — worth flagging rather than silently
-- treating old data as current.
local STALE_DATA_DAYS = 10
function RS:IsDataStale()
    local m = RecommendedStatsData_Meta
    local age = m and RS:DaysSince(m.updated)
    return age ~= nil and age > STALE_DATA_DAYS
end

-- How many verified players this key's targets/BiS actually came from (RecommendedStatsNode's
-- aggregate.js -> Data/SampleSize.lua), which early in a tier can be well below the configured
-- target (Meta.sampleSize) — a fresh raid can be sitting at 1 verified player for a spec while
-- the footer/BiS sub-label used to always just say "top 20" regardless. nil (not 0) when this
-- key isn't in the table yet — an empty/placeholder SampleSize.lua before the next real build,
-- or a schema this old build never shipped it for — so callers fall back to the old wording
-- instead of claiming "0 players" for data that's actually there.
function RS:GetSampleSizeFor(key)
    return key and RecommendedStatsData_SampleSize and RecommendedStatsData_SampleSize[key]
end

-- "Low" relative to the configured target, not some fixed absolute floor — a spec sitting at
-- 8 of a 20-player target is still "low" the same way 1 of 20 is, just less severely so; the
-- UI doesn't currently distinguish degrees, only whether the target was met.
function RS:IsSampleSizeLow(key)
    local n = RS:GetSampleSizeFor(key)
    local target = RecommendedStatsData_Meta and RecommendedStatsData_Meta.sampleSize
    return n ~= nil and target ~= nil and n < target
end

function RS:Evaluate()
    if not RS:SchemaOK() then return nil, "schema" end
    local key = RS:GetKey()
    local targets = key and RecommendedStatsData_Targets[key]
    if not targets then return nil, key end
    local cur, ratings, out = ReadStats(), ReadRatings(), {}
    for _, name in ipairs({ "haste", "crit", "mastery", "versatility" }) do
        local c, t = cur[name], targets[name]
        -- 90th-percentile reading among top players (RecommendedStatsNode's aggregate.js), stored
        -- alongside the median target as e.g. targets.hasteHigh — nil for data built before this
        -- field existed, so callers below must treat it as optional, same as targetRating.
        local high = targets[name .. "High"]
        if t and c ~= nil then
            -- Blizzard's Secret Values system (Patch 12.0+) marks these getters
            -- SecretWhenUnitStatsRestricted: while inside an instance and/or in combat, `c`
            -- becomes an opaque value addon code cannot subtract or compare — only hand off to
            -- sanctioned sinks (SetFormattedText, StatusBar:SetValue). state="secret" tells the
            -- UI to still render the bar/percentage via those, just without a verdict.
            -- `rating` (raw combat rating, ReadRatings above) gets the same treatment — passed
            -- through to SetFormattedText untouched rather than compared/subtracted, since
            -- GetCombatRating is presumably restricted under the same rule as the percent getters.
            if issecretvalue(c) then
                out[#out+1] = { name = name, current = c, target = t, delta = nil, state = "secret", rating = ratings[name], high = high }
            else
                local delta = c - t
                local state = (math.abs(delta) < 0.5) and "on" or (delta < 0) and "under" or "over"
                local r = ratings[name]
                -- Estimated rating-per-percent, derived from the player's own current rating/percent
                -- (same technique as BiSWindow.lua's RatingConversion) — computed here rather than in
                -- the UI layer since `c` is only safe to divide in this non-secret branch. Used to show
                -- the target and delta in rating terms too, not just percent. nil (not a guessed 0)
                -- when `c` is 0 (nothing to derive a rate from) so callers fall back to percent-only.
                -- `r` is checked for secrecy independently of `c` (confirmed live: GetCombatRating can
                -- be secret) — and that check must short-circuit BEFORE `r / c` below, not alongside
                -- it, the same ordering bug BiSWindow.lua's own copy of this pattern hit live.
                local rSecret = r and issecretvalue and issecretvalue(r)
                local ratingPerPercent = (r and not rSecret and c ~= 0) and (r / c) or nil
                local targetRating = ratingPerPercent and (t * ratingPerPercent) or nil
                local deltaRating = ratingPerPercent and (delta * ratingPerPercent) or nil
                -- Same estimated rating-per-percent conversion as targetRating above, applied to
                -- the p90 "high" reading instead of the median target — nil under the same
                -- conditions (secret rating, or a 0% current reading with nothing to derive from).
                local highRating = (high and ratingPerPercent) and (high * ratingPerPercent) or nil
                out[#out+1] = {
                    name = name, current = c, target = t, delta = delta, state = state, rating = r,
                    targetRating = targetRating, deltaRating = deltaRating, high = high, highRating = highRating,
                }
            end
        end
    end
    return out, key
end

RS.listeners = {}
function RS:Refresh()
    local data, key = RS:Evaluate()
    for _, fn in ipairs(RS.listeners) do fn(data, key) end
end

--------------------------------------------------------------------------------
-- Panel visibility (attach mode + minimap toggle)
--------------------------------------------------------------------------------
-- The character-sheet window must never be created/shown just because stats got
-- recomputed (that happens on login via PLAYER_ENTERING_WORLD, long before the
-- player has opened anything) — only these explicit triggers should cause the
-- merged window to appear: CharacterFrame showing (attach mode only), the
-- minimap-icon toggle, or restoring a standalone (unattached) window left open
-- last session. RS.visibilitySyncers holds one "create-if-needed and apply
-- Show/Hide" closure per registrant — CharacterPanel.lua's builds/shows the one
-- physical window, BiSWindow.lua's just lazily builds its content into it.
RS.visibilitySyncers = {}

function RS:ShouldShowPanels()
    RecommendedStatsDB = RecommendedStatsDB or {}
    if RecommendedStatsDB.panelsShown == false then return false end
    if RS:GetAttachMode() == "FREE" then return true end
    return CharacterFrame:IsShown()
end

function RS:SyncVisibility()
    for _, fn in ipairs(RS.visibilitySyncers) do fn() end
    -- Always after the loop above: CharacterPanel.lua's own entry runs FIRST (TOC load order)
    -- and creates RS.bisPage, but BiSWindow.lua's entry (which actually populates it via
    -- EnsureContent) runs SECOND — rendering here, before the loop finishes, would fill
    -- CharacterPanel.lua's own rows fine but always find BiSWindow.lua's page still empty.
    RS:Refresh()
    RS:SyncTabs() -- also after: needs the now-current data above to decide empty-state, etc.
end

--------------------------------------------------------------------------------
-- Tabs — "Recommended Stats" and "BiS Gear" share one merged window (UI/CharacterPanel.lua)
--------------------------------------------------------------------------------
-- Falls back to whichever tab IS enabled (RS:GetShowStats()/RS:GetShowBiS(), toggled from the
-- options panel) if the stored choice got disabled, rather than persisting a tab selection
-- that's no longer available to show.
function RS:GetActiveTab()
    RecommendedStatsDB = RecommendedStatsDB or {}
    local tab = RecommendedStatsDB.activeTab or "STATS"
    if tab == "STATS" and not RS:GetShowStats() and RS:GetShowBiS() then return "BIS" end
    if tab == "BIS" and not RS:GetShowBiS() and RS:GetShowStats() then return "STATS" end
    return tab
end
function RS:SetActiveTab(tab)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.activeTab = tab
    RS:SyncTabs()
end

-- One "show/hide my page (and, for CharacterPanel.lua, update the tab buttons' own look)"
-- closure per registrant. Always run after RS.visibilitySyncers (see RS:SyncVisibility above),
-- so a page that's only built lazily the first time the merged window appears is guaranteed to
-- exist by the time this fires.
RS.tabSyncers = {}
function RS:SyncTabs()
    for _, fn in ipairs(RS.tabSyncers) do fn() end
end

-- Shared by the minimap toggle and the Escape-to-close handler (UI/CharacterPanel.lua) —
-- the latter needs an explicit false rather than a blind flip, since Escape's own
-- UISpecialFrames handling calls this from the window's OnHide script.
function RS:SetPanelsShown(shown)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.panelsShown = shown
    RS:SyncVisibility()
end

-- Minimap left-click: toggle both panels on/off regardless of attach mode.
function RS:TogglePanelsShown()
    RS:SetPanelsShown(not (RecommendedStatsDB.panelsShown ~= false))
end

--------------------------------------------------------------------------------
-- Movable/detachable panel positioning — stored in RecommendedStatsDBChar (## Saved
-- VariablesPerCharacter in the .toc), NOT the account-wide RecommendedStatsDB above. A
-- position dragged on one character has no reason to relocate every other character's
-- panel too, especially across characters running different UI layouts/resolutions.
--
-- One-time migration: positions used to live in the account-wide DB by mistake, so the
-- first login on each character after this changed, whatever was there gets copied into
-- this character's own copy and cleared from the account-wide table.
--------------------------------------------------------------------------------
RecommendedStatsDBChar = RecommendedStatsDBChar or {}
do
    RecommendedStatsDB = RecommendedStatsDB or {}
    if RecommendedStatsDBChar.panelPos == nil and RecommendedStatsDB.panelPos ~= nil then
        RecommendedStatsDBChar.panelPos = RecommendedStatsDB.panelPos
        RecommendedStatsDB.panelPos = nil
    end
end

-- Other addons (Chonky Character Sheet's own M+ side panel, MyCharacterSheet's
-- optional side panel, etc.) may already occupy the space to the right of the
-- character frame. Panels default to docking there but remember a dragged
-- position in SavedVariables so they can be fully detached and placed anywhere.
-- RS.resetters collects one "put me back at the default dock point" closure per
-- panel so /rs resetpos can restore all of them without those panels exposing
-- their internals to Core.lua.
RS.resetters = {}

function RS:MakeMovable(frame, dbKey, applyDefault)
    RecommendedStatsDBChar = RecommendedStatsDBChar or {}
    RS.resetters[dbKey] = applyDefault

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        RecommendedStatsDBChar[dbKey] = { point = point, x = x, y = y }
    end)

    local pos = RecommendedStatsDBChar[dbKey]
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        applyDefault()
    end
end

-- Re-applies the default dock point, but only for panels the user hasn't dragged
-- (an explicit saved position means they've deliberately detached it).
function RS:RedockIfDefault(dbKey)
    RecommendedStatsDBChar = RecommendedStatsDBChar or {}
    if not RecommendedStatsDBChar[dbKey] and RS.resetters[dbKey] then
        RS.resetters[dbKey]()
    end
end

-- Counts real logins only (isInitialLogin — see below), never /reload, so features gated on
-- "the player has actually used this a few times" (UI/RatingNudge.lua) aren't tripped by
-- someone reloading their UI five times in one sitting while tweaking something unrelated.
function RS:BumpLoginCount()
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.loginCount = (RecommendedStatsDB.loginCount or 0) + 1
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED",
                     "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE" }) do
    f:RegisterEvent(e)
end
f:SetScript("OnEvent", function(_, event, isInitialLogin)
    RS:Refresh()
    -- Only on login: restores a standalone (unattached) panel left open last session, pings
    -- chat once if fresh data landed since this player last saw it, and (isInitialLogin only —
    -- PLAYER_ENTERING_WORLD's 2nd arg, false on a /reload) bumps the login counter. Attach-mode
    -- visibility is otherwise driven entirely by CharacterFrame's own OnShow/OnHide, not by
    -- this stat-recompute event.
    if event == "PLAYER_ENTERING_WORLD" then
        RS:SyncVisibility()
        RS:AnnounceDataUpdateIfNew()
        if isInitialLogin then RS:BumpLoginCount() end
    end
end)

-- Slash command: /rs raid | mythicplus | resetpos | options  (or /rs to print status)
SLASH_RECSTATS1 = "/rs"
SlashCmdList.RECSTATS = function(msg)
    msg = (msg or ""):gsub("%s", ""):lower()
    if msg == "m+" or msg == "mplus" then msg = "mythicplus" end
    if msg == "resetpos" then
        RecommendedStatsDBChar = RecommendedStatsDBChar or {}
        for dbKey, applyDefault in pairs(RS.resetters) do
            RecommendedStatsDBChar[dbKey] = nil
            applyDefault()
        end
        print(L.CHAT_PREFIX .. L.MSG_POSITIONS_RESET)
        return
    end
    if msg == "options" or msg == "config" then
        if RS.OpenOptions then RS:OpenOptions() end
        return
    end
    -- "/rs skin export|import" collapses to "skinexport"/"skinimport" after the whitespace
    -- strip above (same as "mythicplus"/"m+" do) — the actual code text goes through
    -- UI/SkinShare.lua's popup EditBox, never through this lowercased command string.
    if msg == "skinexport" then
        if RS.ShowSkinExport then RS:ShowSkinExport() end
        return
    end
    if msg == "skinimport" then
        if RS.ShowSkinImport then RS:ShowSkinImport() end
        return
    end
    local map = { raid="RAID", mythicplus="MYTHICPLUS" }
    if map[msg] then RS:SetContent(map[msg])
    else print(L.CHAT_PREFIX .. L.MSG_CONTENT_STATUS:format(RS:GetContent())) end
end
