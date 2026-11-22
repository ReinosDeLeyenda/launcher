local addonName, NS = ...
local mainUI = NS.mainUI
local LEFT_W = NS.LEFT_PANEL_WIDTH
local CENTER_W = NS.CENTER_WIDTH

function NS.SetCharacterTabVisible(visible)
    if NS.SetEquipmentPanelVisible then NS.SetEquipmentPanelVisible(visible) end
    if NS.SetStatsPanelVisible then NS.SetStatsPanelVisible(visible) end
end

function NS.InitCharacterTab()
    NS.CleanFrameTextures(PaperDollFrame)
    for _, extFrame in ipairs({ CharacterAttributesFrame, PersonalGearScore, GearScore2 }) do
        if extFrame then extFrame:Hide(); extFrame.Show = function() end end
    end

    local anchors = {
        { CharacterHeadSlot, "TOPLEFT", PaperDollFrame, "TOPLEFT", LEFT_W + 18, -74 },
        { CharacterHandsSlot, "TOPLEFT", PaperDollFrame, "TOPLEFT", LEFT_W + 302, -74 },
        { GearManagerToggleButton, "BOTTOM", CharacterHandsSlot, "TOP", 0, 4 },
        { CharacterMainHandSlot, "TOPLEFT", PaperDollFrame, "TOPLEFT", LEFT_W + 118, -392 },
        { CharacterModelFrameRotateLeftButton, "BOTTOMRIGHT", CharacterSecondaryHandSlot, "TOP", -2, 4 },
        { CharacterModelFrameRotateRightButton, "BOTTOMLEFT", CharacterSecondaryHandSlot, "TOP", 2, 4 },
        { CharacterModelFrame, "TOPLEFT", PaperDollFrame, "TOPLEFT", LEFT_W + 62, -76 },
        { CharacterResistanceFrame, "RIGHT", CharacterModelFrame, "RIGHT", -4, 0 },
        { CharacterNameText, "TOP", PaperDollFrame, "TOPLEFT", LEFT_W + 180, -18 },
        { CharacterTitleText, "TOP", CharacterNameText, "BOTTOM", 0, -2 },
        { CharacterLevelText, "TOP", CharacterTitleText, "BOTTOM", 0, -2 },
    }
    for _, a in ipairs(anchors) do
        local frame, point, rel, relPoint, x, y = unpack(a)
        if frame and rel then
            frame:ClearAllPoints()
            frame:SetPoint(point, rel, relPoint, x, y)
        end
    end

    if CharacterModelFrame then CharacterModelFrame:SetSize(234, 310) end
    if CharacterResistanceFrame then CharacterResistanceFrame:SetScale(0.85) end

    if GearManagerDialog then
        NS.CleanFrameTextures(GearManagerDialog)
        NS.ApplyIceBackdrop(GearManagerDialog, 0.95, 0.05, 0.14, 0.24, 16, 4)
        GearManagerDialog:SetSize(CENTER_W + 2, 112)
        GearManagerDialog:SetFrameLevel(mainUI:GetFrameLevel())

        local cover = GearManagerDialog:CreateTexture(nil, "OVERLAY")
        cover:SetTexture(0.05, 0.14, 0.24, 1.0)
        cover:SetHeight(8)
        cover:SetPoint("BOTTOMLEFT", GearManagerDialog, "BOTTOMLEFT", 4, -4)
        cover:SetPoint("BOTTOMRIGHT", GearManagerDialog, "BOTTOMRIGHT", -4, -4)

        local gmAnchors = {
            { GearManagerDialogTitle, "TOPLEFT", GearManagerDialog, "TOPLEFT", 16, -10 },
            { GearManagerDialogCloseButton, "TOPRIGHT", GearManagerDialog, "TOPRIGHT", -2, -2 },
            { GearSetButton1, "TOPLEFT", GearManagerDialog, "TOPLEFT", 16, -28 },
            { GearManagerDialogSaveSet, "TOPRIGHT", GearManagerDialog, "TOPRIGHT", -16, -28 },
            { GearManagerDialogEquipSet, "TOP", GearManagerDialogSaveSet, "BOTTOM", 0, -4 },
            { GearManagerDialogDeleteSet, "TOP", GearManagerDialogEquipSet, "BOTTOM", 0, -4 },
        }
        for _, a in ipairs(gmAnchors) do
            local frame, point, rel, relPoint, x, y = unpack(a)
            if frame and rel then
                frame:ClearAllPoints()
                frame:SetPoint(point, rel, relPoint, x, y)
            end
        end

        if GearManagerDialogTitle then GearManagerDialogTitle:SetTextColor(0.70, 0.90, 0.99) end
        for _, btn in ipairs({ GearManagerDialogSaveSet, GearManagerDialogEquipSet, GearManagerDialogDeleteSet }) do
            if btn then btn:SetSize(76, 20) end
        end

        local function DockGearManager()
            GearManagerDialog:ClearAllPoints()
            GearManagerDialog:SetPoint("BOTTOMLEFT", mainUI, "TOPLEFT", LEFT_W - 1, -4)
        end
        DockGearManager()
        GearManagerDialog:HookScript("OnShow", DockGearManager)
    end
end
