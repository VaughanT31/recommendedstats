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
    [577] = "HAVOC",          [581] = "VENGEANCE",                                -- Demon Hunter
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
        local c, t = cur[name] or 0, targets[name]
        if t then
            local delta = c - t
            local state = (math.abs(delta) < 0.5) and "on" or (delta < 0) and "under" or "over"
            out[#out+1] = { name=name, current=c, target=t, delta=delta, state=state }
        end
    end
    return out, key
end

RS.listeners = {}
function RS:Refresh()
    local data, key = RS:Evaluate()
    for _, fn in ipairs(RS.listeners) do fn(data, key) end
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED",
                     "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE" }) do
    f:RegisterEvent(e)
end
f:SetScript("OnEvent", function() RS:Refresh() end)

-- Slash command: /rs raid | mythicplus  (or /rs to print status)
SLASH_RECSTATS1 = "/rs"
SlashCmdList.RECSTATS = function(msg)
    msg = (msg or ""):gsub("%s", ""):lower()
    if msg == "m+" or msg == "mplus" then msg = "mythicplus" end
    local map = { raid="RAID", mythicplus="MYTHICPLUS" }
    if map[msg] then RS:SetContent(map[msg])
    else print("|cff33ff99RecommendedStats|r content = " .. RS:GetContent() .. "  (use /rs raid|mythicplus)") end
end
