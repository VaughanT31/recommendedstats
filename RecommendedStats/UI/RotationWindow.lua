-- RecommendedStats :: UI/RotationWindow.lua
-- One window (opened by the "Rotation" button on the main panel, or /rs rotation) laying out how
-- top players of your spec and hero talent tree actually play it, in four columns: Opener, Mid
-- Rotation, Filler, When to use CDs. Every spell and buff is an icon with its real tooltip, plus a
-- line on how top players use it. A dropdown picks one raid boss or all of them pooled: a council
-- or add fight is played differently from a single target one.
-- The data (Data/Rotation.lua, RecommendedStatsNode/src/rotation.js) is read from the combat logs
-- of top-parsing raid kills and carries spell ids only, so names, icons and tooltips come from
-- the game in the player's own language.
-- A static reference, not a combat helper: it reads nothing about the fight in progress, so it
-- has nothing to do with Secret Values and works the same in or out of combat.

local RS = RecommendedStats
local L = RecommendedStats_Locale

--------------------------------------------------------------------------------
-- Look
--------------------------------------------------------------------------------
local GOLD           = { 1, 0.82, 0.2 }
local WHITE          = { 1, 1, 1 }
local SOFT           = { 0.85, 0.85, 0.88 }
local DIM            = { 0.62, 0.62, 0.66 }
local AMBER          = { 0.95, 0.65, 0.3 } -- same amber as the stats panel's stale-data footer
local ICON_BORDER    = { 0.28, 0.29, 0.33 }
local DEFAULT_BORDER = { 0.25, 0.27, 0.33 }
local TAB_ACTIVE_BG  = { 0.16, 0.17, 0.22, 1 }
local TAB_IDLE_BG    = { 0.043, 0.047, 0.063, 1 }

local PAD        = 16
local COL_GAP    = 20  -- the separator line sits in the middle of this
local CONTROLS_Y = -66 -- hero tree toggle / "showing another tree" notice
local HEADERS_Y  = -98 -- column titles
local BODY_Y     = -124
local ICON       = 28
local SMALL_ICON = 20
local ROW_GAP    = 9

local COLUMNS = {
    { key = "opener", width = 180, title = L.ROTATION_COL_OPENER },
    { key = "core",   width = 290, title = L.ROTATION_COL_CORE },
    { key = "filler", width = 180, title = L.ROTATION_COL_FILLER },
    { key = "cds",    width = 250, title = L.ROTATION_COL_CDS },
}
local BODY_W = 0
for i, col in ipairs(COLUMNS) do
    col.x = BODY_W
    BODY_W = BODY_W + col.width + (i < #COLUMNS and COL_GAP or 0)
end

local function BorderColor()
    if RS:GetSkin() == "DEFAULT" then return DEFAULT_BORDER end
    return RS:GetAccentColor()
end

local function StyleBackdrop(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(0.043, 0.047, 0.063, 0.97)
    local b = BorderColor()
    frame:SetBackdropBorderColor(b[1], b[2], b[3], 0.7)
end

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------
-- The hero tree the player is running, or nil (none picked yet, or the API isn't there).
local function ActiveTreeID()
    if C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
        return C_ClassTalents.GetActiveHeroTalentSpec()
    end
end

-- A hero tree's name in the player's language, falling back to the English one in the data.
local function TreeName(treeID, tree)
    if treeID and treeID ~= 0 and C_Traits and C_Traits.GetSubTreeInfo and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()
        local info = configID and C_Traits.GetSubTreeInfo(configID, treeID)
        if info and info.name and info.name ~= "" then return info.name end
    end
    return tree and tree.name ~= "" and tree.name or nil
end

local chosenTree -- a tree picked with the toggle this session; nil = follow the player's own

-- This spec's data: the overall guide, with .bosses = the same guide per boss.
local function SpecData()
    return RecommendedStatsData_Rotation and RecommendedStatsData_Rotation[RS:GetSpecKey() or ""]
end

-- The boss picked in the dropdown (its encounter id), or nil for all bosses pooled. Stored
-- account-wide like the talents window's scope, and checked against what the data has now: a
-- data update or a spec change can take a boss's guide away, and the choice then falls back to
-- Overall rather than showing nothing.
local function GetBoss(spec)
    RecommendedStatsDB = RecommendedStatsDB or {}
    local wanted = RecommendedStatsDB.rotationBoss
    for _, boss in ipairs(spec and spec.bosses or {}) do
        if boss.id == wanted then return boss end
    end
    return nil
end
local function SetBoss(id)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.rotationBoss = id
end

-- Which tree to show: { entry=, boss=, treeID=, tree=, notice= } or nil + a reason. entry is the
-- guide being shown (the spec's overall one, or one boss's).
local function Resolve()
    local spec = SpecData()
    if not spec or not spec.order or #spec.order == 0 then return nil, L.ROTATION_NO_DATA end
    local boss = GetBoss(spec)
    local entry = boss or spec

    local mine = ActiveTreeID()
    local wanted = chosenTree or mine
    local treeID = entry.order[1]
    for _, id in ipairs(entry.order) do
        if id == wanted then treeID = id end
    end
    local tree = entry.trees[tostring(treeID)]
    if not tree then return nil, L.ROTATION_NO_DATA end

    -- The player's own tree has no data: top players barely run it, so there is nothing to read a
    -- rotation from. Say so rather than silently showing the other tree's.
    local notice
    if mine and mine ~= 0 and not entry.trees[tostring(mine)] then
        notice = L.ROTATION_OTHER_TREE:format(TreeName(mine) or "?", TreeName(treeID, tree) or "?")
    end
    return { entry = entry, boss = boss, treeID = treeID, tree = tree, notice = notice }
end

--------------------------------------------------------------------------------
-- Window pieces (pooled: a refresh hides everything and hands the same widgets out again)
--------------------------------------------------------------------------------
local frame, body, titleText, subtitleText, messageText, noticeText, bossDropdown
local iconPool, textPool, togglePool = {}, {}, {}
local usedIcons, usedTexts = 0, 0
local missingNames -- true when a spell's name wasn't loaded yet during the last refresh

local function SpellName(id, tree)
    local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if name and name ~= "" then return name end
    missingNames = true
    if id and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
    return (tree.names and tree.names[tostring(id)]) or "?"
end

local function IconOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID then GameTooltip:SetSpellByID(self.spellID) end
    if GameTooltip:NumLines() == 0 then GameTooltip:SetText(self.fallbackName or "?", 1, 1, 1) end
    if self.tips and #self.tips > 0 then
        GameTooltip:AddLine(" ")
        for _, line in ipairs(self.tips) do GameTooltip:AddLine(line, GOLD[1], GOLD[2], GOLD[3], true) end
    end
    GameTooltip:Show()
end

-- A spell (grey border) or buff (gold border) icon at x, y inside the body.
local function PlaceIcon(x, y, size, id, tree, tips, isBuff)
    usedIcons = usedIcons + 1
    local b = iconPool[usedIcons]
    if not b then
        b = CreateFrame("Frame", nil, body)
        b:EnableMouse(true)
        b.border = b:CreateTexture(nil, "BACKGROUND")
        b.border:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b:SetScript("OnEnter", IconOnEnter)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        iconPool[usedIcons] = b
    end
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
    b.spellID, b.tips, b.fallbackName = id, tips, SpellName(id, tree)
    b.icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400)
    local c = isBuff and GOLD or ICON_BORDER
    b.border:SetColorTexture(c[1], c[2], c[3], 1)
    b:Show()
    return b
end

-- Wrapped text at x, y inside the body. Returns its height.
local function PlaceText(x, y, width, font, text, color)
    usedTexts = usedTexts + 1
    local fs = textPool[usedTexts]
    if not fs then
        fs = body:CreateFontString(nil, "OVERLAY", font)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        textPool[usedTexts] = fs
    end
    fs:SetFontObject(font)
    fs:SetWidth(width)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
    fs:SetText(text)
    fs:SetTextColor(color[1], color[2], color[3])
    fs:Show()
    return fs:GetStringHeight()
end

local function HideBody()
    for _, b in ipairs(iconPool) do b:Hide() end
    for _, fs in ipairs(textPool) do fs:Hide() end
    usedIcons, usedTexts = 0, 0
end

-- Icon with a title beside it and detail lines under the title. details = { { text, color }, ... }.
-- Returns the y below the row.
local function SpellRow(x, y, width, id, tree, title, details, tips, size)
    size = size or ICON
    PlaceIcon(x, y, size, id, tree, tips)
    local textX, textW = x + size + 8, width - size - 8
    local h = PlaceText(textX, y, textW, "GameFontHighlight", title, WHITE)
    for _, d in ipairs(details or {}) do
        h = h + 2 + PlaceText(textX, y + h + 2, textW, "GameFontHighlightSmall", d[1], d[2] or DIM)
    end
    return y + math.max(size, h) + ROW_GAP
end

-- A small gold heading inside a column.
local function Section(x, y, width, text)
    return y + PlaceText(x, y, width, "GameFontNormalSmall", text, GOLD) + 6
end

-- "dmg" is the ability's share of the player's output: damage, or healing on a healer's tree.
local function Shares(e, tree)
    return (tree.healer and L.ROTATION_SHARES_HEALER or L.ROTATION_SHARES):format(e.share or 0, e.dmg or 0)
end

-- 122 -> "2 min", 93 -> "1.5 min", 43 -> "43 sec"
local function Duration(seconds)
    if seconds >= 60 then
        return L.ROTATION_MINUTES:format(("%g"):format(math.floor(seconds / 30 + 0.5) / 2))
    end
    return L.ROTATION_SECONDS:format(math.floor(seconds + 0.5))
end

-- 3 -> "3", 5.5 -> "5.5" (medians can land on a half)
local function Number(n)
    return ("%g"):format(n or 0)
end

--------------------------------------------------------------------------------
-- The four columns. Each returns the height it used.
--------------------------------------------------------------------------------
local function RenderOpener(col, tree)
    local y = 0
    if tree.healer then
        return PlaceText(col.x, y, col.width, "GameFontHighlightSmall", L.ROTATION_HEALER_OPENER, DIM)
    end
    for i, o in ipairs(tree.opener or {}) do
        local title = ("%d. %s"):format(i, SpellName(o.id, tree))
        if (o.n or 1) > 1 then title = title .. "  |cffffd133x" .. o.n .. "|r" end
        y = SpellRow(col.x, y, col.width, o.id, tree, title, nil, { L.ROTATION_TIP_OPENER:format(o.pct or 0) }, 24) - 3
    end
    if tree.openerItems then
        y = y + 6 + PlaceText(col.x, y + 6, col.width, "GameFontHighlightSmall", L.ROTATION_ITEMS_OPENER, DIM)
    end
    return y
end

local function RenderCore(col, tree)
    local y = 0
    if tree.core and #tree.core > 0 then
        y = Section(col.x, y, col.width, L.ROTATION_SECTION_PRESSES)
        for _, e in ipairs(tree.core) do
            local details = { { Shares(e, tree) } }
            local how
            if e.kind == "cooldown" then
                how = L.ROTATION_KIND_COOLDOWN:format(Duration(e.every or 0))
            elseif e.kind == "spender" then
                how = e.at and L.ROTATION_KIND_SPENDER_AT:format(Number(e.at)) or L.ROTATION_KIND_SPENDER
            elseif e.kind == "proc" and e.buff then
                how = L.ROTATION_KIND_PROC:format(SpellName(e.buff, tree))
            end
            if e.rank then
                local rank = L.ROTATION_EMPOWER_RANK:format(Number(e.rank))
                how = how and (how .. ". " .. rank) or rank
            end
            if how then details[#details + 1] = { how, SOFT } end
            y = SpellRow(col.x, y, col.width, e.id, tree, SpellName(e.id, tree), details, { Shares(e, tree) })
        end
    end

    if tree.procs and #tree.procs > 0 then
        y = Section(col.x, y + 4, col.width, L.ROTATION_SECTION_PROCS)
        for _, p in ipairs(tree.procs) do
            -- [what gives it] > [the buff] > [what spends it]
            local x = col.x
            local fromNames = {}
            for _, id in ipairs(p.from or {}) do
                PlaceIcon(x, y, SMALL_ICON + 4, id, tree)
                fromNames[#fromNames + 1] = SpellName(id, tree)
                x = x + SMALL_ICON + 8
            end
            if #fromNames > 0 then
                PlaceText(x, y + 5, 12, "GameFontHighlight", ">", DIM)
                x = x + 14
            end
            local buffName = SpellName(p.buff, tree)
            PlaceIcon(x, y, SMALL_ICON + 4, p.buff, tree, { L.ROTATION_TIP_BUFF:format(p.up or 0, p.perFight or 0) }, true)
            x = x + SMALL_ICON + 8
            PlaceText(x, y + 5, 12, "GameFontHighlight", ">", DIM)
            x = x + 14
            PlaceIcon(x, y, SMALL_ICON + 4, p.by, tree)
            y = y + SMALL_ICON + 4 + 4

            local line = (#fromNames > 0)
                and L.ROTATION_PROC_FROM:format(buffName, table.concat(fromNames, L.ROTATION_AND))
                or L.ROTATION_PROC_RANDOM:format(buffName)
            line = line .. " " .. L.ROTATION_PROC_BY:format(SpellName(p.by, tree))
            y = y + PlaceText(col.x, y, col.width, "GameFontHighlightSmall", line, SOFT)
            if p.stacks then
                y = y + 2 + PlaceText(col.x, y + 2, col.width, "GameFontHighlightSmall", L.ROTATION_PROC_STACKS:format(p.stacks), GOLD)
            end
            y = y + ROW_GAP + 2
        end
    end
    return y
end

local function RenderFiller(col, tree)
    local y = 0
    if not tree.filler or #tree.filler == 0 then
        return PlaceText(col.x, y, col.width, "GameFontHighlightSmall", L.ROTATION_FILLER_NONE, DIM)
    end
    for _, e in ipairs(tree.filler) do
        y = SpellRow(col.x, y, col.width, e.id, tree, SpellName(e.id, tree), { { Shares(e, tree) } }, { Shares(e, tree) })
    end
    return y + PlaceText(col.x, y, col.width, "GameFontHighlightSmall", L.ROTATION_FILLER_HINT, DIM)
end

-- "Press with:" followed by small icons on the next line. Returns the y below them.
local function IconLine(col, y, label, ids, tree)
    y = y + PlaceText(col.x + ICON + 8, y, col.width - ICON - 8, "GameFontHighlightSmall", label, SOFT) + 3
    local x = col.x + ICON + 8
    for _, id in ipairs(ids) do
        PlaceIcon(x, y, SMALL_ICON, id, tree)
        x = x + SMALL_ICON + 4
    end
    return y + SMALL_ICON + 4
end

local function RenderCooldowns(col, tree)
    local y = 0
    if tree.healer then
        return PlaceText(col.x, y, col.width, "GameFontHighlightSmall", L.ROTATION_HEALER_CDS, DIM)
    end
    if not tree.cds or #tree.cds == 0 then
        return PlaceText(col.x, y, col.width, "GameFontHighlightSmall", L.ROTATION_CDS_NONE, DIM)
    end
    for _, c in ipairs(tree.cds) do
        local first = (c.first or 0) <= 5 and L.ROTATION_CD_ON_PULL or L.ROTATION_CD_FIRST_AT:format(Duration(c.first))
        local timing
        if (c.every or 0) > 0 then
            timing = L.ROTATION_CD_TIMING:format(first, Duration(c.every))
        else
            timing = L.ROTATION_CD_TIMING_ONCE:format(first)
        end
        local rowEnd = SpellRow(col.x, y, col.width, c.id, tree, SpellName(c.id, tree), { { timing, SOFT } },
            { L.ROTATION_TIP_CD:format(Number(c.perFight)) })
        y = rowEnd - ROW_GAP + 2
        if c.together and #c.together > 0 then y = IconLine(col, y, L.ROTATION_CD_TOGETHER, c.together, tree) end
        if c.inside and #c.inside > 0 then y = IconLine(col, y, L.ROTATION_CD_INSIDE, c.inside, tree) end
        if c.items then
            y = y + PlaceText(col.x + ICON + 8, y, col.width - ICON - 8, "GameFontHighlightSmall", L.ROTATION_ITEMS_CD, DIM) + 2
        end
        y = y + ROW_GAP
    end
    return y
end

local RENDERERS = { opener = RenderOpener, core = RenderCore, filler = RenderFiller, cds = RenderCooldowns }

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------
local function SetFrameHeight(bodyH)
    frame:SetHeight(-BODY_Y + bodyH + PAD)
    StyleBackdrop(frame) -- a plain SetHeight leaves the border drawn at the old size
end

local Refresh

-- One button per hero tree that has data, shown only when there's a choice to make.
local function LayoutToggles(resolved)
    local order = resolved and resolved.entry.order or {}
    local accent = RS:GetAccentColor()
    local x = PAD
    for i, treeID in ipairs(order) do
        local btn = togglePool[i]
        if not btn then
            btn = CreateFrame("Button", nil, frame)
            btn:SetHeight(24)
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.label:SetPoint("CENTER")
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            btn:SetScript("OnClick", function(self)
                chosenTree = self.treeID
                Refresh()
            end)
            togglePool[i] = btn
        end
        btn.treeID = treeID
        btn.label:SetText(TreeName(treeID, resolved.entry.trees[tostring(treeID)]) or "?")
        btn:SetWidth(math.max(96, btn.label:GetStringWidth() + 24))
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", x, CONTROLS_Y)
        local active = treeID == resolved.treeID
        btn.bg:SetColorTexture(unpack(active and TAB_ACTIVE_BG or TAB_IDLE_BG))
        local c = active and accent or DIM
        btn.label:SetTextColor(c[1], c[2], c[3])
        btn:SetShown(#order > 1)
        if #order > 1 then x = x + btn:GetWidth() + 4 end
    end
    for i = #order + 1, #togglePool do togglePool[i]:Hide() end
    return x
end

local BOSS_DROPDOWN_W = 250

-- fromMenu is true only for the boss dropdown's own radio click, which is mid-menu and must not
-- rebuild the menu it is closing (same as the talents window's scope dropdown).
Refresh = function(fromMenu)
    if not (frame and frame:IsShown()) then return end
    HideBody()
    missingNames = false

    -- The list of bosses depends on the spec, and a selected radio's text only changes when the
    -- menu is regenerated.
    local spec = SpecData()
    if not fromMenu and bossDropdown.GenerateMenu then bossDropdown:GenerateMenu() end
    local boss = GetBoss(spec)
    bossDropdown:SetDefaultText(boss and boss.name or L.ROTATION_BOSS_OVERALL)
    bossDropdown:SetShown(spec ~= nil and spec.bosses ~= nil and #spec.bosses > 0)

    local specName = ""
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then specName = select(2, GetSpecializationInfo(specIndex)) or "" end

    local resolved, reason = Resolve()
    local noticeX = LayoutToggles(resolved)
    for _, col in ipairs(COLUMNS) do
        col.header:SetShown(resolved ~= nil)
        if col.line then col.line:SetShown(resolved ~= nil) end
    end

    if not resolved then
        titleText:SetText(L.ROTATION_TITLE:format(specName))
        subtitleText:SetText("")
        noticeText:SetText("")
        messageText:SetText(reason)
        messageText:Show()
        SetFrameHeight(140)
        return
    end
    messageText:Hide()

    local tree, entry = resolved.tree, resolved.entry
    local treeName = TreeName(resolved.treeID, tree)
    titleText:SetText(treeName and L.ROTATION_TITLE_TREE:format(specName, treeName) or L.ROTATION_TITLE:format(specName))
    local difficulty = L.TALENTS_DIFFICULTY[entry.difficulty] or entry.difficulty or "?"
    if resolved.boss then
        subtitleText:SetText(L.ROTATION_SUBTITLE_BOSS:format(resolved.boss.name, tree.fights or 0, difficulty, tree.players or 0))
    else
        subtitleText:SetText(L.ROTATION_SUBTITLE:format(tree.fights or 0, difficulty, tree.players or 0))
    end
    noticeText:ClearAllPoints()
    noticeX = noticeX + (noticeX > PAD and 8 or 0)
    noticeText:SetPoint("TOPLEFT", noticeX, CONTROLS_Y - 5)
    noticeText:SetWidth(BODY_W + PAD - noticeX - BOSS_DROPDOWN_W - 12)
    noticeText:SetText(resolved.notice or "")

    local accent = RS:GetAccentColor()
    local tallest = 0
    for _, col in ipairs(COLUMNS) do
        col.header:SetTextColor(accent[1], accent[2], accent[3])
        tallest = math.max(tallest, RENDERERS[col.key](col, tree))
    end
    SetFrameHeight(tallest)

    -- A spell the client hadn't loaded yet came out with its English fallback name: once, a moment
    -- later, draw again with the real one.
    if missingNames and not frame.retried then
        frame.retried = true
        C_Timer.After(0.6, function() Refresh() end)
    end
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local function EnsureWindow()
    if frame then return end

    frame = CreateFrame("Frame", "RecommendedStatsRotation", UIParent, "BackdropTemplate")
    frame:SetSize(BODY_W + 2 * PAD, 400)
    -- Same layering as the talents window (see UI/TalentsWindow.lua for why DIALOG).
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    StyleBackdrop(frame)
    RS:MakeMovable(frame, "rotationPos", function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end)
    tinsert(UISpecialFrames, "RecommendedStatsRotation")

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", PAD, -14)

    subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", subtitleText, "BOTTOMLEFT", 0, -4)
    -- The data's own age: it is refreshed far less often than the stat targets (about monthly, or
    -- after a patch), so say which patch and date it was read on.
    local meta = RecommendedStatsData_RotationMeta
    if meta and meta.updated then
        hint:SetText(L.ROTATION_HINT .. "  " .. L.ROTATION_DATA_AGE:format(meta.gamePatch or "?", meta.updated))
    else
        hint:SetText(L.ROTATION_HINT)
    end

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- "My pulls": the player's own page on the RecommendedStats Analyzer site, where their logged
    -- raid pulls are compared with these same top players (Core.lua RS:ShowAnalyzerLink).
    local pulls = CreateFrame("Button", nil, frame)
    pulls:SetHeight(22)
    pulls:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, -6)
    pulls.bg = pulls:CreateTexture(nil, "BACKGROUND")
    pulls.bg:SetAllPoints()
    pulls.bg:SetColorTexture(unpack(TAB_ACTIVE_BG))
    pulls.label = pulls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pulls.label:SetPoint("CENTER")
    pulls.label:SetText(L.ANALYZER_BUTTON)
    pulls:SetWidth(pulls.label:GetStringWidth() + 24)
    local pullsHL = pulls:CreateTexture(nil, "HIGHLIGHT")
    pullsHL:SetAllPoints()
    pullsHL:SetColorTexture(1, 1, 1, 0.06)
    pulls:SetScript("OnShow", function(self)
        local c = RS:GetAccentColor()
        self.label:SetTextColor(c[1], c[2], c[3])
    end)
    pulls:SetScript("OnClick", function() RS:ShowAnalyzerLink() end)
    pulls:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.ANALYZER_BUTTON)
        GameTooltip:AddLine(L.ANALYZER_BUTTON_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    pulls:SetScript("OnLeave", GameTooltip_Hide)

    noticeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noticeText:SetTextColor(AMBER[1], AMBER[2], AMBER[3])
    noticeText:SetJustifyH("LEFT")

    -- Boss picker, right end of the controls row. Same modern dropdown as the talents window's.
    bossDropdown = CreateFrame("DropdownButton", "RecommendedStatsRotationBoss", frame, "WowStyle1DropdownTemplate")
    bossDropdown:SetWidth(BOSS_DROPDOWN_W)
    bossDropdown:SetPoint("TOPRIGHT", -PAD, CONTROLS_Y + 2)
    bossDropdown:SetupMenu(function(_, root)
        local spec = SpecData()
        local function Add(text, id)
            root:CreateRadio(
                text,
                function()
                    local current = GetBoss(SpecData())
                    return (current and current.id or nil) == id
                end,
                function()
                    SetBoss(id)
                    chosenTree = nil -- a tree picked for one boss may have no guide on another
                    Refresh(true)
                    -- Close rather than MenuResponse.Refresh: see the talents window's scope
                    -- dropdown, where Refresh never moved the radio dot on an open menu.
                    return MenuResponse.Close
                end
            )
        end
        Add(L.ROTATION_BOSS_OVERALL, nil)
        for _, boss in ipairs(spec and spec.bosses or {}) do Add(boss.name, boss.id) end
    end)

    body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", PAD, BODY_Y)
    body:SetSize(BODY_W, 10)

    for i, col in ipairs(COLUMNS) do
        col.header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        col.header:SetPoint("TOPLEFT", PAD + col.x, HEADERS_Y)
        col.header:SetText(col.title)
        if i < #COLUMNS then
            col.line = frame:CreateTexture(nil, "ARTWORK")
            col.line:SetColorTexture(1, 1, 1, 0.08)
            col.line:SetWidth(1)
            col.line:SetPoint("TOP", frame, "TOPLEFT", PAD + col.x + col.width + COL_GAP / 2, HEADERS_Y)
            col.line:SetPoint("BOTTOM", frame, "BOTTOMLEFT", PAD + col.x + col.width + COL_GAP / 2, PAD)
        end
    end

    messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    messageText:SetPoint("TOP", 0, CONTROLS_Y - 10)
    messageText:SetWidth(500)
    messageText:Hide()

    frame:SetScript("OnShow", function(self)
        self:Raise()
        self.retried = false
        Refresh()
    end)

    -- CreateFrame returns a SHOWN frame; without this the first toggle would hide it again
    -- (same trap as the talents window).
    frame:Hide()
end

function RS:ToggleRotation()
    EnsureWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

--------------------------------------------------------------------------------
-- Keeping an open window correct
--------------------------------------------------------------------------------
-- A spec change swaps the data key, a talent change can swap the hero tree. Either way a tree
-- picked by hand no longer means anything. Delayed a beat, like the talents window: the new
-- config isn't always readable the instant the event fires.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:SetScript("OnEvent", function()
    chosenTree = nil
    if frame then frame.retried = false end
    C_Timer.After(0.5, function() Refresh() end)
end)

table.insert(RS.skinListeners, function()
    if frame then
        StyleBackdrop(frame)
        Refresh()
    end
end)
