local addonName, NS = ...

local function StyleGlyphSlot(glyphBtn)
    if not glyphBtn or glyphBtn._mcuiSkinned then return end
    glyphBtn._mcuiSkinned = true

    local name = glyphBtn:GetName()
    local ring = _G[name .. "Ring"]
    if ring then
        ring:SetVertexColor(0.35, 0.80, 1.0)
    end
    local highlight = _G[name .. "Highlight"]
    if highlight then
        highlight:SetVertexColor(0.55, 0.90, 1.0)
    end
end

local function ApplyGlyphTheme()
    if not GlyphFrame or GlyphFrame._mcuiSkinned then return end
    GlyphFrame._mcuiSkinned = true

    NS.CleanFrameTextures(GlyphFrame)

    if GlyphFrameBackground then
        GlyphFrameBackground:SetVertexColor(0.35, 0.78, 1.0, 0.85)
    end

    if GlyphFrameTitle then
        GlyphFrameTitle:SetTextColor(0.75, 0.92, 1.0)
    end

    for i = 1, 6 do
        local glyphBtn = _G["GlyphFrameGlyph" .. i]
        StyleGlyphSlot(glyphBtn)
    end
end

function NS.InitGlyphsTheme()
    if IsAddOnLoaded("Blizzard_GlyphUI") then
        ApplyGlyphTheme()
    else
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, event, loadedAddon)
            if loadedAddon == "Blizzard_GlyphUI" then
                ApplyGlyphTheme()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end
