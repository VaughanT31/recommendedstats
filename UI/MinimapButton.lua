-- RecommendedStats :: UI/MinimapButton.lua
-- Small draggable button docked to the minimap ring. Left-click toggles both
-- panels (RS:TogglePanelsShown); right-click opens the options panel. No
-- LibDBIcon dependency — this addon has no other libs, so it's simplest to just
-- own the ~20 lines of minimap-ring math directly.
--
-- Depends on Core.lua providing:
--   RS:TogglePanelsShown() / RS:OpenOptions() (UI/OptionsPanel.lua)

local RS = RecommendedStats

local RADIUS = 80 -- distance from Minimap center, in pixels

local function GetSavedAngle()
    RecommendedStatsDB = RecommendedStatsDB or {}
    return RecommendedStatsDB.minimapAngle or 220
end

local function SetSavedAngle(angle)
    RecommendedStatsDB = RecommendedStatsDB or {}
    RecommendedStatsDB.minimapAngle = angle
end

local button = CreateFrame("Button", "RecommendedStatsMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", 0, 0)

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 1, 1)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own edge so it doesn't clip against the ring
icon:SetTexture("Interface\\AddOns\\RecommendedStats\\icon")

local function PlaceAtAngle(angle)
    local rad = math.rad(angle)
    local x, y = math.cos(rad) * RADIUS, math.sin(rad) * RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

PlaceAtAngle(GetSavedAngle())

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        PlaceAtAngle(angle)
        SetSavedAngle(angle)
    end)
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        if RS.OpenOptions then RS:OpenOptions() end
    else
        RS:TogglePanelsShown()
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Recommended Stats")
    GameTooltip:AddLine("Left-click: show/hide panels", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-click: options", 0.9, 0.9, 0.9)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)
