local addonName, NS = ...

local function StyleGuildBankSlot(btn)
    if not btn or btn._mcuiSkinned then return end
    btn._mcuiSkinned = true

    local normal = _G[btn:GetName() .. "NormalTexture"] or btn:GetNormalTexture()
    if normal then
        normal:SetTexture("")
        normal:Hide()
    end

    NS.ApplyIceBackdrop(btn, 0.85, 0.04, 0.10, 0.18, 8, 1)

    local icon = _G[btn:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
end

local function ApplyGuildBankTheme()
    if not GuildBankFrame or GuildBankFrame._mcuiSkinned then return end
    GuildBankFrame._mcuiSkinned = true

    NS.CleanFrameTextures(GuildBankFrame)
    NS.ApplyIceBackdrop(GuildBankFrame, 0.95, 0.05, 0.14, 0.24, 16, 4)
    NS.AddTopGlow(GuildBankFrame, 50, 0.38, 4)

    for _, emblem in ipairs({
        GuildBankEmblemFrame,
        GuildBankFrameLeft, GuildBankFrameMiddle, GuildBankFrameRight,
        GuildBankTabTitleBackground, GuildBankTabTitleBackgroundLeft,
        GuildBankTabTitleBackgroundRight, GuildBankTabLimitBackground,
        GuildBankTabLimitBackgroundLeft, GuildBankTabLimitBackgroundRight
    }) do
        if emblem then
            if emblem.GetRegions then NS.CleanFrameTextures(emblem) end
            if emblem.SetTexture then emblem:SetTexture("") end
            emblem:Hide()
        end
    end

    for _, title in ipairs({ GuildBankTabTitle, GuildBankLimitLabel }) do
        if title then title:SetTextColor(0.75, 0.92, 1.0) end
    end

    local closeBtn = GuildBankFrameCloseButton or _G["GuildBankFrameCloseButton"]
    if closeBtn then
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", GuildBankFrame, "TOPRIGHT", -4, -4)
    end

    -- Columnas y casillas de objetos (7 columnas x 14 filas)
    for col = 1, 7 do
        local colFrame = _G["GuildBankColumn" .. col]
        if colFrame then
            NS.CleanFrameTextures(colFrame)
            for row = 1, 14 do
                local btn = _G["GuildBankColumn" .. col .. "Button" .. row]
                StyleGuildBankSlot(btn)
            end
        end
    end

    -- Pestañas laterales de bóvedas (1 a 6)
    for i = 1, 6 do
        local tab = _G["GuildBankTab" .. i]
        local btn = _G["GuildBankTab" .. i .. "Button"]
        if tab then NS.CleanFrameTextures(tab) end
        if btn then
            StyleGuildBankSlot(btn)
            local icon = _G["GuildBankTab" .. i .. "ButtonIconTexture"]
            if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        end
    end

    -- Pestañas inferiores (Banco, Registro, Registro de dinero, Info)
    for i = 1, 4 do
        local bTab = _G["GuildBankFrameTab" .. i]
        if bTab then
            NS.CleanFrameTextures(bTab)
            NS.ApplyIceBackdrop(bTab, 0.90, 0.05, 0.14, 0.24, 8, 1)
        end
    end

    -- Marcos de registros e información de pestaña
    for _, scroll in ipairs({ GuildBankTransactionsScrollFrame, GuildBankInfoScrollFrame }) do
        if scroll then
            NS.TintFrameRegions(scroll)
        end
    end

    -- Ventana emergente de edición de icono/nombre de pestaña
    if GuildBankPopupFrame then
        NS.CleanFrameTextures(GuildBankPopupFrame)
        NS.ApplyIceBackdrop(GuildBankPopupFrame, 0.96, 0.05, 0.14, 0.25, 16, 4)
        NS.AddTopGlow(GuildBankPopupFrame, 36, 0.35, 4)
        if GuildBankPopupNameLeft then GuildBankPopupNameLeft:Hide() end
        if GuildBankPopupNameMiddle then GuildBankPopupNameMiddle:Hide() end
        if GuildBankPopupNameRight then GuildBankPopupNameRight:Hide() end
        if GuildBankPopupEditBox then
            NS.ApplyIceBackdrop(GuildBankPopupEditBox, 0.90, 0.04, 0.10, 0.18, 8, 1)
        end
        for i = 1, 16 do
            local pBtn = _G["GuildBankPopupButton" .. i]
            StyleGuildBankSlot(pBtn)
        end
    end
end

function NS.InitGuildBankTheme()
    if IsAddOnLoaded("Blizzard_GuildBankUI") then
        ApplyGuildBankTheme()
    else
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, event, loadedAddon)
            if loadedAddon == "Blizzard_GuildBankUI" then
                ApplyGuildBankTheme()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end
