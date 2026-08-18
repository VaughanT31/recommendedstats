local ADDON = ...
RecommendedStats = RecommendedStats or {}
local RS = RecommendedStats
local EXPECTED_SCHEMA = 1

-- ⚠ VERIFY these return PERCENT (not rating) on live 12.1 before shipping (see scope.md §11).
local function ReadStats()
    return {
        haste       = GetHaste(),
        crit        = GetCritChance(),        -- casters: GetSpellCritChance()
        mastery     = GetMasteryEffect(),
        versatility = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE),
    }
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
    print("|cff33ff99RecommendedStats|r content set to " .. c)
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

function RS:GetKey()
    local class, spec = GetClassToken(), GetSpecToken()
    if not (class and spec) then return nil end
    return class .. "_" .. spec .. "_" .. RS:GetContent()
end

function RS:SchemaOK()
    local m = RecommendedStatsData_Meta
    return m and m.schema == EXPECTED_SCHEMA
end

function RS:Evaluate()
    if not RS:SchemaOK() then return nil, "schema" end
    local key = RS:GetKey()
    local targets = key and RecommendedStatsData_Targets[key]
    if not targets then return nil, key end
    local cur, out = ReadStats(), {}
    for _, name in ipairs({ "haste", "crit", "mastery", "versatility" }) do
        local c, t = cur[name], targets[name]
        if t and c ~= nil then
            -- Blizzard's Secret Values system (Patch 12.0+) marks these getters
            -- SecretWhenUnitStatsRestricted: while inside an instance and/or in combat, `c`
            -- becomes an opaque value addon code cannot subtract or compare — only hand off to
            -- sanctioned sinks (SetFormattedText, StatusBar:SetValue). state="secret" tells the
            -- UI to still render the bar/percentage via those, just without a verdict.
            if issecretvalue(c) then
                out[#out+1] = { name = name, current = c, target = t, delta = nil, state = "secret" }
            else
                local delta = c - t
                local state = (math.abs(delta) < 0.5) and "on" or (delta < 0) and "under" or "over"
                out[#out+1] = { name = name, current = c, target = t, delta = delta, state = state }
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
-- The character-sheet panels must never be created/shown just because stats got
-- recomputed (that happens on login via PLAYER_ENTERING_WORLD, long before the
-- player has opened anything) — only these explicit triggers should cause a panel
-- to appear: CharacterFrame showing (attach mode only), the minimap-icon toggle,
-- or restoring a standalone (unattached) panel that was left open last session.
-- RS.visibilitySyncers holds one "create-if-needed and apply Show/Hide" closure
-- per panel, registered by CharacterPanel.lua / BiSWindow.lua.
RS.visibilitySyncers = {}

function RS:ShouldShowPanels()
    RecommendedStatsDB = RecommendedStatsDB or {}
    if RecommendedStatsDB.panelsShown == false then return false end
    if RS:GetAttachMode() == "FREE" then return true end
    return CharacterFrame:IsShown()
end

function RS:SyncVisibility()
    for _, fn in ipairs(RS.visibilitySyncers) do fn() end
end

-- Minimap left-click: toggle both panels on/off regardless of attach mode.
function RS:TogglePanelsShown()
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.panelsShown = not (RecommendedStatsDB.panelsShown ~= false)
    RS:SyncVisibility()
end

--------------------------------------------------------------------------------
-- Movable/detachable panel positioning
--------------------------------------------------------------------------------
-- Other addons (Chonky Character Sheet's own M+ side panel, MyCharacterSheet's
-- optional side panel, etc.) may already occupy the space to the right of the
-- character frame. Panels default to docking there but remember a dragged
-- position in SavedVariables so they can be fully detached and placed anywhere.
-- RS.resetters collects one "put me back at the default dock point" closure per
-- panel so /rs resetpos can restore all of them without those panels exposing
-- their internals to Core.lua.
RS.resetters = {}

function RS:MakeMovable(frame, dbKey, applyDefault)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RS.resetters[dbKey] = applyDefault

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        RecommendedStatsDB[dbKey] = { point = point, x = x, y = y }
    end)

    local pos = RecommendedStatsDB[dbKey]
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
    RecommendedStatsDB = RecommendedStatsDB or {}
    if not RecommendedStatsDB[dbKey] and RS.resetters[dbKey] then
        RS.resetters[dbKey]()
    end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED",
                     "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE" }) do
    f:RegisterEvent(e)
end
f:SetScript("OnEvent", function(_, event)
    RS:Refresh()
    -- Only on login: restores a standalone (unattached) panel left open last session.
    -- Attach-mode visibility is otherwise driven entirely by CharacterFrame's own
    -- OnShow/OnHide, not by this stat-recompute event.
    if event == "PLAYER_ENTERING_WORLD" then RS:SyncVisibility() end
end)

-- Slash command: /rs raid | mythicplus | resetpos | options  (or /rs to print status)
SLASH_RECSTATS1 = "/rs"
SlashCmdList.RECSTATS = function(msg)
    msg = (msg or ""):gsub("%s", ""):lower()
    if msg == "m+" or msg == "mplus" then msg = "mythicplus" end
    if msg == "resetpos" then
        RecommendedStatsDB = RecommendedStatsDB or {}
        for dbKey, applyDefault in pairs(RS.resetters) do
            RecommendedStatsDB[dbKey] = nil
            applyDefault()
        end
        print("|cff33ff99RecommendedStats|r panel positions reset. Drag a panel to move it again.")
        return
    end
    if msg == "options" or msg == "config" then
        if RS.OpenOptions then RS:OpenOptions() end
        return
    end
    local map = { raid="RAID", mythicplus="MYTHICPLUS" }
    if map[msg] then RS:SetContent(map[msg])
    else print("|cff33ff99RecommendedStats|r content = " .. RS:GetContent() .. "  (use /rs raid|mythicplus|resetpos|options)") end
end
