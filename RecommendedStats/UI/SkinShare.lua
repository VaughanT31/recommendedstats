-- RecommendedStats :: UI/SkinShare.lua
-- Export/import a short code for the current skin (Default/Class Color/Custom Color, plus its
-- RGB for Custom) so players can share a look with guildies/Discord without describing it in
-- words. Deliberately scoped to just the skin, not a general settings-sync feature.
--
-- Depends on Core.lua providing: RS:GetSkin()/RS:SetSkin() / RS:GetCustomColor()/
-- RS:SetCustomColor() -- and UI/CopyPopup.lua providing RS:ShowCopyPopup().

local RS = RecommendedStats

local PREFIX = "RSSKIN1"

local function ToHex(c)
    return ("%02X%02X%02X"):format(
        math.floor(c[1] * 255 + 0.5),
        math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5)
    )
end

local function FromHex(hex)
    if #hex ~= 6 or hex:match("%X") then return nil end
    local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return r / 255, g / 255, b / 255
end

function RS:ExportSkinString()
    local skin = RS:GetSkin()
    if skin == "CUSTOM" then
        return ("%s:CUSTOM:%s"):format(PREFIX, ToHex(RS:GetCustomColor()))
    end
    return ("%s:%s"):format(PREFIX, skin)
end

-- Returns true on success, or false + a human-readable reason on a malformed/unrecognized
-- string — UI/CopyPopup.lua's editable mode expects exactly this (ok, message) shape.
function RS:ImportSkinString(str)
    str = (str or ""):gsub("%s", "")
    local skin, hex = str:match("^" .. PREFIX .. ":([%u]+):?(%x*)$")
    if not skin then return false, "Not a RecommendedStats skin code." end

    if skin == "CUSTOM" then
        local r, g, b = FromHex(hex)
        if not r then return false, "Custom skin code is missing/invalid color data." end
        RS:SetCustomColor(r, g, b)
        RS:SetSkin("CUSTOM")
    elseif skin == "CLASS" or skin == "DEFAULT" then
        RS:SetSkin(skin)
    else
        return false, ("Unrecognized skin \"%s\"."):format(skin)
    end
    return true, "Skin applied."
end

function RS:ShowSkinExport()
    RS:ShowCopyPopup({
        title = "Export Skin",
        hint = "Copy this code and share it (Ctrl+A, Ctrl+C):",
        text = RS:ExportSkinString(),
    })
end

function RS:ShowSkinImport()
    RS:ShowCopyPopup({
        title = "Import Skin",
        hint = "Paste a RecommendedStats skin code:",
        editable = true,
        buttonText = "Apply",
        onAction = function(text) return RS:ImportSkinString(text) end,
    })
end
