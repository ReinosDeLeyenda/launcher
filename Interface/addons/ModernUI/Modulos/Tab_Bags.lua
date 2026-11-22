-- ==================== INICIO PARTE 1: CONFIGURACION Y RANURAS ====================
local addonName, NS = ...

-- Azul glaciar vibrante (tono de logros obtenidos)
local ICE_BG_R, ICE_BG_G, ICE_BG_B, ICE_BG_A = 0.06, 0.24, 0.50, 0.96
local ICE_BD_R, ICE_BD_G, ICE_BD_B = 0.70, 0.93, 1.0

local function ApplyIceBackdrop(frame, bgAlpha, r, g, b)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(r or ICE_BG_R, g or ICE_BG_G, b or ICE_BG_B, bgAlpha or ICE_BG_A)
    frame:SetBackdropBorderColor(ICE_BD_R, ICE_BD_G, ICE_BD_B, 1.0)
end

local function AddTopGlow(frame, height)
    if not frame or frame.iceGlow then return end
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    glow:SetHeight(height or 34)
    glow:SetGradientAlpha("VERTICAL", 0.14, 0.45, 0.85, 0.0, 0.55, 0.88, 1.0, 0.55)
    frame.iceGlow = glow
end

-- Tiñe tanto el borde como el fondo de hueco vacio de cada casilla
local function StyleItemSlot(itemBtn)
    if not itemBtn then return end
    local name = itemBtn:GetName() or ""

    local normalTex = itemBtn:GetNormalTexture()
    if normalTex then
        normalTex:SetDesaturated(true)
        normalTex:SetVertexColor(0.55, 0.88, 1.0, 0.95)
    end

    local iconTex = (name ~= "" and _G[name .. "IconTexture"]) or itemBtn.icon
    if iconTex then
        local texPath = iconTex:GetTexture() or ""
        if not itemBtn.hasItem or string.find(texPath, "EmptySlot") or string.find(texPath, "UI%-Backpack") then
            iconTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            iconTex:SetVertexColor(0.10, 0.36, 0.68, 0.85)
        else
            iconTex:SetVertexColor(1, 1, 1, 1)
        end
    end

    for _, region in ipairs({ itemBtn:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= iconTex and region ~= normalTex then
            local rTex = region:GetTexture() or ""
            if string.find(rTex, "EmptySlot") or string.find(rTex, "Slot") then
                region:SetDesaturated(true)
                region:SetVertexColor(0.14, 0.45, 0.80, 0.90)
            end
        end
    end
end

local function StripCombuctorTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if tex and not string.find(tex, "Icons") and not string.find(tex, "UI%-CheckBox") then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end
end
-- ==================== FIN PARTE 1 ====================

-- ==================== INICIO PARTE 2: MARCOS COMBUCTOR Y BLIZZARD ====================
local function PaintAllChildSlots(parent)
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:IsObjectType("Button") and (child.hasItem ~= nil or child.icon or _G[(child:GetName() or "") .. "IconTexture"]) then
            StyleItemSlot(child)
        elseif child:IsShown() then
            PaintAllChildSlots(child)
        end
    end
end

local function SkinCombuctorFrame(frame)
    if not frame then return end
    local name = frame:GetName()

    StripCombuctorTextures(frame)
    if frame.portrait then frame.portrait:Hide() end
    if name and _G[name .. "Portrait"] then _G[name .. "Portrait"]:Hide() end

    ApplyIceBackdrop(frame, 0.96)
    AddTopGlow(frame, 44)

    if not frame.iceCombuctorHooked then
        frame.iceCombuctorHooked = true

        for _, child in ipairs({ frame:GetChildren() }) do
            local cName = child:GetName() or ""
            if string.find(cName, "Tab") or string.find(cName, "Filter") then
                StripCombuctorTextures(child)
                ApplyIceBackdrop(child, 0.92, 0.05, 0.18, 0.40)
            elseif child:IsObjectType("EditBox") or string.find(cName, "Search") then
                StripCombuctorTextures(child)
                ApplyIceBackdrop(child, 0.90, 0.04, 0.14, 0.30)
            end
        end

        frame:HookScript("OnShow", function(self)
            StripCombuctorTextures(self)
            ApplyIceBackdrop(self, 0.96)
            PaintAllChildSlots(self)
        end)

        frame:HookScript("OnUpdate", function(self)
            if not self.iceSlotTimer or (GetTime() - self.iceSlotTimer > 0.25) then
                self.iceSlotTimer = GetTime()
                local r, g, b = self:GetBackdropColor()
                if not r or r < 0.05 or b < 0.40 then
                    StripCombuctorTextures(self)
                    ApplyIceBackdrop(self, 0.96)
                end
                PaintAllChildSlots(self)
            end
        end)
    end
end

local function StyleBlizzardContainerFrame(frame)
    if not frame then return end
    local name = frame:GetName()
    local texturesToHide = {
        name .. "BackgroundTop", name .. "BackgroundMiddle1",
        name .. "BackgroundMiddle2", name .. "BackgroundBottom",
        name .. "Background1Slot", name .. "Portrait"
    }
    for _, texName in ipairs(texturesToHide) do
        local tex = _G[texName]
        if tex then
            if tex.SetTexture then tex:SetTexture(nil) end
            tex:Hide()
        end
    end
    if frame.Portrait then frame.Portrait:Hide() end

    if not frame.iceBg then
        local bg = CreateFrame("Frame", nil, frame)
        bg:SetFrameLevel(math.max(1, frame:GetFrameLevel() - 1))
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        ApplyIceBackdrop(bg, 0.96)
        AddTopGlow(bg, 28)
        frame.iceBg = bg
    end

    for i = 1, 36 do
        local itemBtn = _G[name .. "Item" .. i]
        if itemBtn then StyleItemSlot(itemBtn) end
    end
end

function NS.InitBagsTheme()
    if ContainerFrame_GenerateFrame then
        hooksecurefunc("ContainerFrame_GenerateFrame", StyleBlizzardContainerFrame)
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf then cf:HookScript("OnShow", StyleBlizzardContainerFrame) end
    end

    local combWatcher = CreateFrame("Frame")
    local elapsedCheck = 0
    combWatcher:SetScript("OnUpdate", function(self, elapsed)
        elapsedCheck = elapsedCheck + elapsed
        if elapsedCheck < 0.5 then return end
        elapsedCheck = 0

        for i = 1, 4 do
            local cf = _G["CombuctorFrame" .. i]
            if cf and not cf.iceCombuctorHooked then
                SkinCombuctorFrame(cf)
            end
        end
    end)
end
-- ==================== FIN PARTE 2 ====================
