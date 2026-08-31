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

local ATTACH_MODES = {
    { text = "Attach to Character Screen", value = "ATTACHED" },
    { text = "Not attached (move freely)", value = "FREE" },
}

local function AttachModeLabel()
    local cur = RS:GetAttachMode()
    for _, m in ipairs(ATTACH_MODES) do if m.value == cur then return m.text end end
    return "Select"
end

local panel = CreateFrame("Frame")
panel.name = "RecommendedStats"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Recommended Stats")

local attachLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
attachLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
attachLabel:SetText("Window position")

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
statsCheck.Text:SetText("Show \"Recommended Stats\" tab")
statsCheck:SetScript("OnClick", function(self)
    RS:SetShowStats(self:GetChecked())
end)

local bisCheck = CreateFrame("CheckButton", "RecommendedStatsShowBiSCheck", panel, "UICheckButtonTemplate")
bisCheck:SetPoint("TOPLEFT", statsCheck, "BOTTOMLEFT", 0, -4)
bisCheck.Text:SetText("Show \"BiS Gear\" tab")
bisCheck:SetScript("OnClick", function(self)
    RS:SetShowBiS(self:GetChecked())
end)

local minimapCheck = CreateFrame("CheckButton", "RecommendedStatsShowMinimapCheck", panel, "UICheckButtonTemplate")
minimapCheck:SetPoint("TOPLEFT", bisCheck, "BOTTOMLEFT", 0, -4)
minimapCheck.Text:SetText("Show minimap icon")
minimapCheck:SetScript("OnClick", function(self)
    RS:SetShowMinimapIcon(self:GetChecked())
end)

--------------------------------------------------------------------------------
-- Row size — how much detail the "Recommended Stats" tab's 4 stat rows show, from a single
-- compact line (no bar) up to today's look plus a delta-from-target line. See
-- UI/CharacterPanel.lua's ROW_H_BY_SIZE/ApplyRowSize for what each option actually renders.
--------------------------------------------------------------------------------
local SIZES = {
    { text = "Default", value = "DEFAULT" },
    { text = "Small",   value = "SMALL" },
    { text = "Medium",  value = "MEDIUM" },
    { text = "Large",   value = "LARGE" },
}

local function SizeLabel()
    local cur = RS:GetStatsSize()
    for _, s in ipairs(SIZES) do if s.value == cur then return s.text end end
    return "Select"
end

local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sizeLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 2, -16)
sizeLabel:SetText("Recommended Stats row size")

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
    { text = "Default",      value = "DEFAULT" },
    { text = "Class Color",  value = "CLASS" },
    { text = "Custom Color", value = "CUSTOM" },
}

local function SkinLabel()
    local cur = RS:GetSkin()
    for _, s in ipairs(SKINS) do if s.value == cur then return s.text end end
    return "Select"
end

local skinLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
skinLabel:SetPoint("TOPLEFT", sizeDropdown, "BOTTOMLEFT", -2, -16)
skinLabel:SetText("Skin")

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
exportBtn:SetText("Export Skin")
exportBtn:SetScript("OnClick", function() if RS.ShowSkinExport then RS:ShowSkinExport() end end)

local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
importBtn:SetSize(110, 22)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
importBtn:SetText("Import Skin")
importBtn:SetScript("OnClick", function() if RS.ShowSkinImport then RS:ShowSkinImport() end end)

--------------------------------------------------------------------------------
-- Disclaimer — sets expectations up front: this is a stat-weight reference, not a DPS
-- increase in itself. Placed last so it reads as a closing note under all the actual settings.
--------------------------------------------------------------------------------
local disclaimer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
disclaimer:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 2, -20)
disclaimer:SetWidth(420)
disclaimer:SetJustifyH("LEFT")
disclaimer:SetText("Recommended Stats won't make you do more DPS by itself — it just helps you hit the correct stat weights for your spec.")

panel:SetScript("OnShow", function()
    attachDropdown:SetDefaultText(AttachModeLabel())
    statsCheck:SetChecked(RS:GetShowStats())
    bisCheck:SetChecked(RS:GetShowBiS())
    minimapCheck:SetChecked(RS:GetShowMinimapIcon())
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
