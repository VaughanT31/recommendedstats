-- RecommendedStats :: UI/OptionsPanel.lua
-- Canvas settings panel, registered under Esc -> Options -> AddOns. Also opened via
-- /rs options and the minimap button's right-click.
--
-- Depends on Core.lua providing:
--   RS:GetAttachMode() / RS:SetAttachMode(mode)   ("ATTACHED" | "FREE")
--   RS:GetShowBiS() / RS:SetShowBiS(shown)

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
attachLabel:SetText("Panel position")

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

local bisCheck = CreateFrame("CheckButton", "RecommendedStatsShowBiSCheck", panel, "UICheckButtonTemplate")
bisCheck:SetPoint("TOPLEFT", attachDropdown, "BOTTOMLEFT", -2, -20)
bisCheck.Text:SetText("Show BiS gear section")
bisCheck:SetScript("OnClick", function(self)
    RS:SetShowBiS(self:GetChecked())
end)

panel:SetScript("OnShow", function()
    attachDropdown:SetDefaultText(AttachModeLabel())
    bisCheck:SetChecked(RS:GetShowBiS())
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
