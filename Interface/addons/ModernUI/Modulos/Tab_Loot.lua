local addonName, NS = ...

local function ApplyQualityBorder(frame, link)
    if not frame then return end
    if link then
        local _, _, quality = GetItemInfo(link)
        if quality and quality >= 2 then
            local r, g, b = GetItemQualityColor(quality)
            frame:SetBackdropBorderColor(r, g, b, 1)
            return
        end
    end
    frame:SetBackdropBorderColor(0.35, 0.72, 0.95, 0.85)
end

local function StyleLootFrame()
    if not LootFrame then return end

    if not LootFrame._mcuiSkinned then
        LootFrame._mcuiSkinned = true
        NS.CleanFrameTextures(LootFrame)
        NS.ApplyIceBackdrop(LootFrame, 0.95, 0.05, 0.14, 0.24, 16, 4)
        NS.AddTopGlow(LootFrame, 36, 0.35, 4)

        if LootFramePortraitOverlay then
            LootFramePortraitOverlay:SetTexture("")
            LootFramePortraitOverlay:Hide()
        end

        if LootCloseButton then
            LootCloseButton:ClearAllPoints()
            LootCloseButton:SetPoint("TOPRIGHT", LootFrame, "TOPRIGHT", -2, -2)
        end

        for i = 1, LOOTFRAME_NUMBUTTONS or 4 do
            local btn = _G["LootButton" .. i]
            if btn then
                local nameFrame = _G["LootButton" .. i .. "NameFrame"]
                if nameFrame then nameFrame:SetTexture("") end

                NS.ApplyIceBackdrop(btn, 0.85, 0.04, 0.11, 0.20, 8, 1)

                local icon = _G["LootButton" .. i .. "IconTexture"]
                if icon then
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    icon:ClearAllPoints()
                    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
                    icon:SetSize(30, 30)
                end

                local normal = btn:GetNormalTexture()
                if normal then normal:SetTexture("") end
            end
        end
    end

    -- Colorea el borde de cada casilla según la rareza del objeto saqueado
    for i = 1, LOOTFRAME_NUMBUTTONS or 4 do
        local btn = _G["LootButton" .. i]
        if btn and btn:IsShown() and btn.slot then
            local link = GetLootSlotLink(btn.slot)
            ApplyQualityBorder(btn, link)
        end
    end
end

local function StyleGroupLootFrame(frame)
    if not frame then return end
    local name = frame:GetName()

    if not frame._mcuiSkinned then
        frame._mcuiSkinned = true
        NS.CleanFrameTextures(frame)
        NS.ApplyIceBackdrop(frame, 0.95, 0.05, 0.14, 0.24, 14, 3)
        NS.AddTopGlow(frame, 28, 0.32, 3)

        local slotFrame = _G[name .. "Slot"]
        if slotFrame then
            NS.CleanFrameTextures(slotFrame)
            NS.ApplyIceBackdrop(slotFrame, 0.90, 0.04, 0.10, 0.18, 8, 1)
        end

        local icon = _G[name .. "IconFrameIcon"]
        if icon then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local timer = _G[name .. "Timer"]
        if timer then
            local barTex = timer:GetStatusBarTexture()
            if barTex then
                barTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
            end
            timer:SetStatusBarColor(0.25, 0.78, 1.0)
        end
    end

    -- Actualiza el color del borde del icono según la calidad del objeto en sorteo
    if frame.rollID then
        local link = GetLootRollItemLink(frame.rollID)
        local slotFrame = _G[name .. "Slot"] or frame
        ApplyQualityBorder(slotFrame, link)
    end
end

function NS.InitLootTheme()
    StyleLootFrame()
    if LootFrame then
        LootFrame:HookScript("OnShow", StyleLootFrame)
    end
    if LootFrame_Update then
        hooksecurefunc("LootFrame_Update", StyleLootFrame)
    end

    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local gf = _G["GroupLootFrame" .. i]
        if gf then
            StyleGroupLootFrame(gf)
            gf:HookScript("OnShow", function(self)
                StyleGroupLootFrame(self)
            end)
        end
    end

    if GroupLootFrame_OnShow then
        hooksecurefunc("GroupLootFrame_OnShow", function(self)
            StyleGroupLootFrame(self)
        end)
    end
end
