-- RecommendedStats :: UI/CopyPopup.lua
-- Shared small popup: title + hint + one text field (read-only "here's a code, copy it" or
-- editable "paste a code here") + one primary button + close. Backs both UI/SkinShare.lua
-- (export/import) and UI/RatingNudge.lua (the CurseForge link) so this chrome only exists once
-- rather than being duplicated per feature.

local RS = RecommendedStats

local popup

local function EnsurePopup()
    if popup then return end

    popup = CreateFrame("Frame", "RecommendedStatsCopyPopup", UIParent, "BackdropTemplate")
    popup:SetSize(380, 118)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    tinsert(UISpecialFrames, "RecommendedStatsCopyPopup") -- Escape closes it like the addon's other windows

    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.043, 0.047, 0.063, 0.97)
    popup:SetBackdropBorderColor(0.25, 0.27, 0.33, 0.7)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOPLEFT", 14, -14)
    popup.title:SetPoint("RIGHT", -30, 0)
    popup.title:SetJustifyH("LEFT")

    popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.hint:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -8)
    popup.hint:SetPoint("RIGHT", -14, 0)
    popup.hint:SetJustifyH("LEFT")

    local boxBG = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    boxBG:SetPoint("TOPLEFT", popup.hint, "BOTTOMLEFT", 0, -8)
    boxBG:SetPoint("RIGHT", -14, 0)
    boxBG:SetHeight(22)
    boxBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    boxBG:SetBackdropColor(0, 0, 0, 0.4)
    boxBG:SetBackdropBorderColor(0.25, 0.27, 0.33, 0.7)

    popup.editBox = CreateFrame("EditBox", nil, boxBG)
    popup.editBox:SetPoint("TOPLEFT", 6, -3)
    popup.editBox:SetPoint("BOTTOMRIGHT", -6, 3)
    popup.editBox:SetAutoFocus(false)
    popup.editBox:SetFontObject(ChatFontNormal)
    popup.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    popup.status = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.status:SetPoint("TOPLEFT", boxBG, "BOTTOMLEFT", 0, -6)

    popup.actionBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.actionBtn:SetSize(100, 22)
    popup.actionBtn:SetPoint("BOTTOM", 0, 12)

    popup.close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.close:SetPoint("TOPRIGHT", 2, 2)
    popup.close:SetScript("OnClick", function() popup:Hide() end)
end

-- opts:
--   title, hint (strings)
--   text        -- read-only mode: pre-filled, auto-highlighted for Ctrl+C
--   editable    -- true for a paste-and-apply box (starts empty)
--   buttonText  -- shown on the action button; omit in read-only mode to hide it entirely
--   onAction    -- editable mode: function(enteredText) -> ok, message (status line, green/red)
--               -- read-only mode: function() called when the button is clicked, then closes
--   onClose     -- called whenever the popup hides, for any reason (button, X, Escape)
function RS:ShowCopyPopup(opts)
    EnsurePopup()
    popup.title:SetText(opts.title)
    popup.hint:SetText(opts.hint)
    popup.status:SetText("")
    popup.editBox:SetScript("OnEnterPressed", nil)
    popup.actionBtn:SetScript("OnClick", nil)

    if opts.editable then
        popup.editBox:SetText("")
        popup.actionBtn:SetText(opts.buttonText or "Apply")
        popup.actionBtn:Show()

        local function Run()
            local ok, message = opts.onAction(popup.editBox:GetText())
            if ok then
                popup.status:SetText("|cff33ff99" .. (message or "Applied.") .. "|r")
            else
                popup.status:SetText("|cffef5c5c" .. (message or "Something went wrong.") .. "|r")
            end
        end
        popup.actionBtn:SetScript("OnClick", Run)
        popup.editBox:SetScript("OnEnterPressed", Run)
    else
        popup.editBox:SetText(opts.text or "")
        popup.editBox:HighlightText()
        if opts.buttonText then
            popup.actionBtn:SetText(opts.buttonText)
            popup.actionBtn:Show()
            popup.actionBtn:SetScript("OnClick", function()
                if opts.onAction then opts.onAction() end
                popup:Hide()
            end)
        else
            popup.actionBtn:Hide()
        end
    end

    popup:SetScript("OnHide", opts.onClose) -- always (re)assigned, so a stale handler from a
                                             -- previous ShowCopyPopup caller can't linger
    popup.editBox:SetFocus()
    popup:Show()
end
