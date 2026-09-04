-- RecommendedStats :: UI/OptionsPanel.lua
-- Canvas settings panel, registered under Esc -> Options -> AddOns. Also opened via
-- /rs options and the minimap button's right-click.
--
-- Depends on Core.lua providing:
--   RS:GetAttachMode() / RS:SetAttachMode(mode)   ("ATTACHED" | "FREE")
--   RS:GetShowBiS() / RS:SetShowBiS(shown)
--   RS:GetShowStats() / RS:SetShowStats(shown)
--   RS:GetShowMinimapIcon() / RS:SetShowMinimapIcon(shown)
--   RS:GetStatsSize() / RS:SetStatsSize(size)     ("DEFAULT" | "SMALL" | "MEDIUM" | "LARGE")

local RS = RecommendedStats
local L = RecommendedStats_Locale

local ATTACH_MODES = {
    { text = L.ATTACH_MODE_ATTACHED, value = "ATTACHED" },
    { text = L.ATTACH_MODE_FREE,     value = "FREE" },
}

local function AttachModeLabel()
    local cur = RS:GetAttachMode()
    for _, m in ipairs(ATTACH_MODES) do if m.value == cur then return m.text end end
    return L.SELECT
end

local panel = CreateFrame("Frame")
panel.name = L.ADDON_TITLE

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L.ADDON_TITLE)

local attachLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
attachLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
attachLabel:SetText(L.OPTIONS_WINDOW_POSITION)

local attachDropdown = CreateFrame("DropdownButton", "RecommendedStatsAttachDropdown", panel, "WowStyle1DropdownTemplate")
attachDropdown:SetWidth(240)
attachDropdown:SetPoint("TOPLEFT", attachLabel, "BOTTOMLEFT", 0, -6)
attachDropdown:SetDefaultText(AttachModeLabel())
attachDropdown:SetupMenu(function(_, root)
    for _, m in ipairs(ATTACH_MODES) do
        root:CreateRadio(
            m.text,
            function() return RS:GetAttachMode() == m.value end,
            function()
                RS:SetAttachMode(m.value)
                attachDropdown:SetDefaultText(AttachModeLabel())
                return MenuResponse.Refresh
            end
        )
    end
end)

local statsCheck = CreateFrame("CheckButton", "RecommendedStatsShowStatsCheck", panel, "UICheckButtonTemplate")
statsCheck:SetPoint("TOPLEFT", attachDropdown, "BOTTOMLEFT", -2, -20)
statsCheck.Text:SetText(L.OPTIONS_SHOW_STATS_TAB)
statsCheck:SetScript("OnClick", function(self)
    RS:SetShowStats(self:GetChecked())
end)

local bisCheck = CreateFrame("CheckButton", "RecommendedStatsShowBiSCheck", panel, "UICheckButtonTemplate")
bisCheck:SetPoint("TOPLEFT", statsCheck, "BOTTOMLEFT", 0, -4)
bisCheck.Text:SetText(L.OPTIONS_SHOW_BIS_TAB)
bisCheck:SetScript("OnClick", function(self)
    RS:SetShowBiS(self:GetChecked())
end)

local minimapCheck = CreateFrame("CheckButton", "RecommendedStatsShowMinimapCheck", panel, "UICheckButtonTemplate")
minimapCheck:SetPoint("TOPLEFT", bisCheck, "BOTTOMLEFT", 0, -4)
minimapCheck.Text:SetText(L.OPTIONS_SHOW_MINIMAP)
minimapCheck:SetScript("OnClick", function(self)
    RS:SetShowMinimapIcon(self:GetChecked())
end)

-- Shape/icon cues alongside the existing red/green/blue state colors (stat panel's under/on/over,
-- BiS gear's status dot) — see Core.lua's RS:GetColorblindMode()/RS:SetColorblindMode().
local colorblindCheck = CreateFrame("CheckButton", "RecommendedStatsColorblindCheck", panel, "UICheckButtonTemplate")
colorblindCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -4)
colorblindCheck.Text:SetText(L.OPTIONS_COLORBLIND)
colorblindCheck:SetScript("OnClick", function(self)
    RS:SetColorblindMode(self:GetChecked())
end)

--------------------------------------------------------------------------------
-- Row size — how much detail the "Recommended Stats" tab's 4 stat rows show, from a single
-- compact line (no bar) up to today's look plus a delta-from-target line. See
-- UI/CharacterPanel.lua's ROW_H_BY_SIZE/ApplyRowSize for what each option actually renders.
--------------------------------------------------------------------------------
local SIZES = {
    { text = L.SIZE_DEFAULT, value = "DEFAULT" },
    { text = L.SIZE_SMALL,   value = "SMALL" },
    { text = L.SIZE_MEDIUM,  value = "MEDIUM" },
    { text = L.SIZE_LARGE,   value = "LARGE" },
}

local function SizeLabel()
    local cur = RS:GetStatsSize()
    for _, s in ipairs(SIZES) do if s.value == cur then return s.text end end
    return L.SELECT
end

local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sizeLabel:SetPoint("TOPLEFT", colorblindCheck, "BOTTOMLEFT", 2, -16)
sizeLabel:SetText(L.OPTIONS_ROW_SIZE)

local sizeDropdown = CreateFrame("DropdownButton", "RecommendedStatsSizeDropdown", panel, "WowStyle1DropdownTemplate")
sizeDropdown:SetWidth(240)
sizeDropdown:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -6)
sizeDropdown:SetDefaultText(SizeLabel())
sizeDropdown:SetupMenu(function(_, root)
    for _, s in ipairs(SIZES) do
        root:CreateRadio(
            s.text,
            function() return RS:GetStatsSize() == s.value end,
            function()
                RS:SetStatsSize(s.value)
                sizeDropdown:SetDefaultText(SizeLabel())
                return MenuResponse.Refresh
            end
        )
    end
end)

--------------------------------------------------------------------------------
-- Skin — accent color for chrome only (active tab text, target tick, panel border,
-- minimap ring). Never affects the stat bar under/on/over colors — see Core.lua's
-- RS:GetAccentColor() for why that's deliberate.
--------------------------------------------------------------------------------
local SKINS = {
    { text = L.SKIN_DEFAULT, value = "DEFAULT" },
    { text = L.SKIN_CLASS,   value = "CLASS" },
    { text = L.SKIN_CUSTOM,  value = "CUSTOM" },
}

local function SkinLabel()
    local cur = RS:GetSkin()
    for _, s in ipairs(SKINS) do if s.value == cur then return s.text end end
    return L.SELECT
end

local skinLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
skinLabel:SetPoint("TOPLEFT", sizeDropdown, "BOTTOMLEFT", -2, -16)
skinLabel:SetText(L.OPTIONS_SKIN)

local skinDropdown = CreateFrame("DropdownButton", "RecommendedStatsSkinDropdown", panel, "WowStyle1DropdownTemplate")
skinDropdown:SetWidth(240)
skinDropdown:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -6)
skinDropdown:SetDefaultText(SkinLabel())

-- Custom color swatch — only shown while Skin = Custom Color. Forward-declared so the
-- dropdown's onSelect below can toggle it the instant Custom is picked, not just on next OnShow.
local customSwatch, RefreshSwatchColor

local function UpdateCustomSwatchShown()
    if customSwatch then customSwatch:SetShown(RS:GetSkin() == "CUSTOM") end
end

skinDropdown:SetupMenu(function(_, root)
    for _, s in ipairs(SKINS) do
        root:CreateRadio(
            s.text,
            function() return RS:GetSkin() == s.value end,
            function()
                RS:SetSkin(s.value)
                skinDropdown:SetDefaultText(SkinLabel())
                UpdateCustomSwatchShown()
                return MenuResponse.Refresh
            end
        )
    end
end)

customSwatch = CreateFrame("Button", "RecommendedStatsCustomColorSwatch", panel)
customSwatch:SetSize(20, 20)
customSwatch:SetPoint("LEFT", skinDropdown, "RIGHT", 12, 0)

local swatchBG = customSwatch:CreateTexture(nil, "BACKGROUND")
swatchBG:SetAllPoints()
swatchBG:SetColorTexture(1, 1, 1, 1)

local swatchBorder = CreateFrame("Frame", nil, customSwatch, "BackdropTemplate")
swatchBorder:SetPoint("TOPLEFT", -1, 1)
swatchBorder:SetPoint("BOTTOMRIGHT", 1, -1)
swatchBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
swatchBorder:SetBackdropBorderColor(0, 0, 0, 1)

RefreshSwatchColor = function()
    local c = RS:GetCustomColor()
    swatchBG:SetColorTexture(c[1], c[2], c[3], 1)
end

-- SetupColorPickerAndShow is the modern (post-10.2.5) color picker API — verify this still
-- resolves if the addon is ever tested against an older client than the one it targets today.
customSwatch:SetScript("OnClick", function()
    local start = RS:GetCustomColor()
    ColorPickerFrame:SetupColorPickerAndShow({
        r = start[1], g = start[2], b = start[3],
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            RS:SetCustomColor(r, g, b)
            RefreshSwatchColor()
        end,
        cancelFunc = function(previousValues)
            RS:SetCustomColor(previousValues.r, previousValues.g, previousValues.b)
            RefreshSwatchColor()
        end,
    })
end)

-- Share a skin as a short code (UI/SkinShare.lua) — a guildie can paste "Import" without
-- either of you describing the color in words.
local exportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
exportBtn:SetSize(110, 22)
exportBtn:SetPoint("TOPLEFT", skinDropdown, "BOTTOMLEFT", 0, -10)
exportBtn:SetText(L.OPTIONS_EXPORT_SKIN)
exportBtn:SetScript("OnClick", function() if RS.ShowSkinExport then RS:ShowSkinExport() end end)

local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
importBtn:SetSize(110, 22)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
importBtn:SetText(L.OPTIONS_IMPORT_SKIN)
importBtn:SetScript("OnClick", function() if RS.ShowSkinImport then RS:ShowSkinImport() end end)

--------------------------------------------------------------------------------
-- Disclaimer — sets expectations up front: this is a stat-weight reference, not a DPS
-- increase in itself. Placed last so it reads as a closing note under all the actual settings.
--------------------------------------------------------------------------------
local disclaimer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
disclaimer:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 2, -20)
disclaimer:SetWidth(420)
disclaimer:SetJustifyH("LEFT")
disclaimer:SetText(L.OPTIONS_DISCLAIMER)

panel:SetScript("OnShow", function()
    attachDropdown:SetDefaultText(AttachModeLabel())
    statsCheck:SetChecked(RS:GetShowStats())
    bisCheck:SetChecked(RS:GetShowBiS())
    minimapCheck:SetChecked(RS:GetShowMinimapIcon())
    colorblindCheck:SetChecked(RS:GetColorblindMode())
    sizeDropdown:SetDefaultText(SizeLabel())
    skinDropdown:SetDefaultText(SkinLabel())
    RefreshSwatchColor()
    UpdateCustomSwatchShown()
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
RS.optionsCategoryID = category:GetID()

function RS:OpenOptions()
    -- Blizzard's settings frame ignores the requested category on the very first
    -- call in a session (long-standing bug); calling twice is the standard workaround.
    Settings.OpenToCategory(RS.optionsCategoryID)
    Settings.OpenToCategory(RS.optionsCategoryID)
end
