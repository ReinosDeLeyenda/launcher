local addonName, NS = ...
local mainUI = NS.mainUI
local GRID_SLOTS = 49
local GRID_COLS = 7

function NS.GetPetsTabWidth()
    return NS.TOTAL_WIDTH
end

local function IsCombatPetSubTabActive()
    return PetPaperDollFramePetFrame and PetPaperDollFramePetFrame:IsShown()
end

local function SetCompanionGridVisible(visible)
    for i = 1, GRID_SLOTS do
        local btn = _G["CompanionButton" .. i]
        if btn then if visible then btn:Show() else btn:Hide() end end
    end
    for _, widget in ipairs({ CompanionPrevPageButton, CompanionNextPageButton, CompanionPageNumber }) do
        if widget then if visible then widget:Show() else widget:Hide() end end
    end
end

local function UpdateExtraCompanionButtons()
    local compFrame = PetPaperDollFrameCompanionFrame
    if not compFrame or not compFrame:IsShown() or IsCombatPetSubTabActive() then
        SetCompanionGridVisible(false)
        if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(false) end
        return
    end

    SetCompanionGridVisible(true)
    if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(true) end

    local mode = compFrame.mode or "CRITTER"
    local page = (mode == "CRITTER") and (compFrame.pageCritter or 0) or (compFrame.pageMount or 0)
    local offset = page * GRID_SLOTS
    local numCompanions = GetNumCompanions(mode) or 0
    local selectedID = (mode == "CRITTER") and compFrame.idCritter or compFrame.idMount

    for i = 1, GRID_SLOTS do
        local btn = _G["CompanionButton" .. i]
        if btn then
            local index = offset + i
            local actTex = _G["CompanionButton" .. i .. "ActiveTexture"]
            if index <= numCompanions then
                local cID, _, sID, icon, active = GetCompanionInfo(mode, index)
                btn.creatureID, btn.spellID, btn.active = cID, sID, active
                btn:SetNormalTexture(icon)
                local nTex = btn:GetNormalTexture()
                if nTex then nTex:SetDesaturated(false); nTex:SetVertexColor(1, 1, 1, 1); nTex:Show() end
                if actTex then if active then actTex:Show() else actTex:Hide() end end
                if cID == selectedID then btn:LockHighlight() else btn:UnlockHighlight() end
                btn:Enable()
            else
                btn.creatureID, btn.spellID, btn.active = nil, nil, nil
                btn:SetNormalTexture("")
                if actTex then actTex:Hide() end
                btn:UnlockHighlight()
                btn:Disable()
            end
        end
    end

    local totalPages = math.max(1, math.ceil(numCompanions / GRID_SLOTS))
    if CompanionPageNumber then CompanionPageNumber:SetFormattedText(MERCHANT_PAGE_NUMBER, page + 1, totalPages) end
    if CompanionPrevPageButton then if page == 0 then CompanionPrevPageButton:Disable() else CompanionPrevPageButton:Enable() end end
    if CompanionNextPageButton then if (page + 1) >= totalPages then CompanionNextPageButton:Disable() else CompanionNextPageButton:Enable() end end
end

local function StyleAndCenterCompanionTabs()
    local visibleTabs = {}
    for i = 1, 3 do
        local tab = _G["PetPaperDollFrameTab" .. i]
        if tab and tab:IsShown() then table.insert(visibleTabs, tab) end
    end

    local tabW = (#visibleTabs == 3) and 88 or 104
    for idx, tab in ipairs(visibleTabs) do
        tab:SetSize(tabW, 24)
        tab:ClearAllPoints()
        if idx == 1 then tab:SetPoint("TOPLEFT", PetPaperDollFrame, "TOPLEFT", 76, -54)
        else tab:SetPoint("LEFT", visibleTabs[idx - 1], "RIGHT", 6, 0) end
        local txt = _G[tab:GetName() .. "Text"]
        if txt then txt:ClearAllPoints(); txt:SetPoint("CENTER", tab, "CENTER", 0, 0) end
    end

    for i = 1, GRID_SLOTS do
        local btn = _G["CompanionButton" .. i]
        if btn then
            btn:SetSize(34, 34)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", PetPaperDollFrame, "TOPLEFT", 24 + (((i - 1) % GRID_COLS) * 40), -104 - (math.floor((i - 1) / GRID_COLS) * 40))
            NS.TintFrameRegions(btn, 0.35, 0.75, 1.0)
            local bg = _G["CompanionButton" .. i .. "Background"]
            if bg then bg:SetVertexColor(0.20, 0.55, 0.95, 0.75) end
        end
    end

    local anchors = {
        { CompanionPrevPageButton, "TOPLEFT", PetPaperDollFrame, "TOPLEFT", 112, -390 },
        { CompanionNextPageButton, "LEFT", CompanionPrevPageButton, "RIGHT", 82, 0 },
        { CompanionPageNumber, "LEFT", CompanionPrevPageButton, "RIGHT", 12, 0 },
        { CompanionModelFrame, "TOPLEFT", mainUI, "TOPLEFT", 325, -76 },
        { CompanionSelectedName, "TOP", CompanionModelFrame, "BOTTOM", 0, -4 },
        { CompanionSummonButton, "TOP", CompanionSelectedName, "BOTTOM", 0, -6 },
        { CompanionModelFrameRotateLeftButton, "TOPRIGHT", CompanionSummonButton, "BOTTOM", -2, -4 },
        { CompanionModelFrameRotateRightButton, "TOPLEFT", CompanionSummonButton, "BOTTOM", 2, -4 },
    }
    for _, a in ipairs(anchors) do
        local f, p, rel, rp, x, y = unpack(a)
        if f and rel then f:ClearAllPoints(); f:SetPoint(p, rel, rp, x, y) end
    end

    if CompanionModelFrame then CompanionModelFrame:SetSize(265, 225) end
    if CompanionSummonButton then CompanionSummonButton:SetSize(130, 22) end
end

function NS.InitPetsTab()
    for i = 1, 3 do
        local subTab = _G["PetPaperDollFrameTab" .. i]
        if subTab then
            NS.CleanFrameTextures(subTab)
            NS.ApplyIceBackdrop(subTab, 0.95, 0.08, 0.24, 0.40, 12, 3)
        end
    end

    COMPANIONS_PER_PAGE = GRID_SLOTS
    if PetPaperDollFrameCompanionFrame then
        for i = 13, GRID_SLOTS do
            if not _G["CompanionButton" .. i] then
                local btn = CreateFrame("Button", "CompanionButton" .. i, PetPaperDollFrameCompanionFrame, "CompanionButtonTemplate")
                btn:SetID(i)
                btn:SetScript("OnEnter", function(self) if self.spellID then CompanionButton_OnEnter(self) end end)
            end
        end
    end

    StyleAndCenterCompanionTabs()
    if PetPaperDollFrame_UpdateCompanions then hooksecurefunc("PetPaperDollFrame_UpdateCompanions", UpdateExtraCompanionButtons) end
    hooksecurefunc("PanelTemplates_TabResize", function(tab)
        if tab == PetPaperDollFrameTab1 or tab == PetPaperDollFrameTab2 or tab == PetPaperDollFrameTab3 then
            tab:SetSize((PetPaperDollFrameTab2 and PetPaperDollFrameTab2:IsShown()) and 88 or 104, 24)
        end
    end)
    hooksecurefunc("PanelTemplates_UpdateTabs", function(frame)
        if frame == PetPaperDollFrame then StyleAndCenterCompanionTabs(); UpdateExtraCompanionButtons() end
    end)
    if PetPaperDollFramePetFrame then
        PetPaperDollFramePetFrame:HookScript("OnShow", function()
            SetCompanionGridVisible(false)
            if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(false) end
            StyleAndCenterCompanionTabs()
        end)
    end
    if PetPaperDollFrameCompanionFrame then
        PetPaperDollFrameCompanionFrame:HookScript("OnShow", function() StyleAndCenterCompanionTabs(); UpdateExtraCompanionButtons() end)
    end
end
