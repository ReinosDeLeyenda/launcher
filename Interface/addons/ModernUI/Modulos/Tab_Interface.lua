local addonName, NS = ...

local ICE_BG_R, ICE_BG_G, ICE_BG_B, ICE_BG_A = 0.05, 0.14, 0.24, 0.94
local ICE_BD_R, ICE_BD_G, ICE_BD_B = 0.45, 0.80, 1.0

local function ApplyIceBackdrop(frame, bgAlpha)
    if not frame then return end
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(ICE_BG_R, ICE_BG_G, ICE_BG_B, bgAlpha or ICE_BG_A)
    frame:SetBackdropBorderColor(ICE_BD_R, ICE_BD_G, ICE_BD_B, 1.0)
end

local function AddTopGlow(frame, height)
    if not frame or frame.iceGlow then return end
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    glow:SetHeight(height or 40)
    glow:SetGradientAlpha("VERTICAL", 0.10, 0.30, 0.48, 0.0, 0.20, 0.55, 0.85, 0.35)
    frame.iceGlow = glow
end

local function TintButtonTextures(btn)
    if not btn then return end
    for _, region in ipairs({ btn:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if tex and not string.find(tex, "Icons") then
                region:SetVertexColor(0.45, 0.82, 1.0)
            end
        end
    end
end

local function StyleInterfaceTab(tabBtn)
    if not tabBtn then return end
    NS.CleanFrameTextures(tabBtn)
    ApplyIceBackdrop(tabBtn, 0.90)
    local txt = _G[tabBtn:GetName() .. "Text"]
    if txt then
        txt:SetTextColor(0.80, 0.94, 1.0)
    end
end

function NS.InitInterfaceTheme()
    if not InterfaceOptionsFrame then return end

    -- 1. Marco principal de Interfaz
    NS.CleanFrameTextures(InterfaceOptionsFrame)
    ApplyIceBackdrop(InterfaceOptionsFrame, 0.94)
    AddTopGlow(InterfaceOptionsFrame, 44)

    -- 2. Encabezado superior (título "Interface")
    if InterfaceOptionsFrameHeader then
        InterfaceOptionsFrameHeader:SetTexture(nil)
        InterfaceOptionsFrameHeader:Hide()
    end
    if InterfaceOptionsFrameHeaderText then
        InterfaceOptionsFrameHeaderText:SetTextColor(0.70, 0.90, 0.99)
    end

    -- 3. Paneles internos (Categorías a la izquierda, AddOns y Panel de opciones a la derecha)
    local innerPanels = {
        InterfaceOptionsFrameCategories,
        InterfaceOptionsFrameAddOns,
        InterfaceOptionsFramePanelContainer
    }
    for _, panel in ipairs(innerPanels) do
        if panel then
            NS.CleanFrameTextures(panel)
            ApplyIceBackdrop(panel, 0.65)
        end
    end

    -- 4. Pestañas superiores ("Game" y "AddOns")
    StyleInterfaceTab(InterfaceOptionsFrameTab1)
    StyleInterfaceTab(InterfaceOptionsFrameTab2)

    -- 5. Botones inferiores (Defaults, Okay, Cancel)
    local buttons = {
        InterfaceOptionsFrameDefaults,
        InterfaceOptionsFrameOkay,
        InterfaceOptionsFrameCancel
    }
    for _, btn in ipairs(buttons) do
        TintButtonTextures(btn)
    end

    -- 6. Barra de desplazamiento de categorías
    if InterfaceOptionsFrameCategoriesListScrollBar then
        NS.CleanFrameTextures(InterfaceOptionsFrameCategoriesListScrollBar)
        TintButtonTextures(InterfaceOptionsFrameCategoriesListScrollBarScrollUpButton)
        TintButtonTextures(InterfaceOptionsFrameCategoriesListScrollBarScrollDownButton)
    end
    if InterfaceOptionsFrameAddOnsListScrollBar then
        NS.CleanFrameTextures(InterfaceOptionsFrameAddOnsListScrollBar)
        TintButtonTextures(InterfaceOptionsFrameAddOnsListScrollBarScrollUpButton)
        TintButtonTextures(InterfaceOptionsFrameAddOnsListScrollBarScrollDownButton)
    end
end
