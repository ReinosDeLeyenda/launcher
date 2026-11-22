local addonName, NS = ...
local styled = false

local function LightenAllFontStrings(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local r, g, b = region:GetTextColor()
            if r < 0.45 and g < 0.45 and b < 0.45 then region:SetTextColor(0.95, 0.99, 1.0) end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        LightenAllFontStrings(child)
    end
end

local function TintSingleAchievementCard(btn)
    if not btn then return end
    local name = btn:GetName()

    local texturesToStrip = {
        name .. "Background", name .. "TitleBackground", name .. "RewardBackground", name .. "Glow",
        name .. "BottomLeftTs", name .. "BottomRightTs", name .. "TopLeftTs", name .. "TopRightTs",
        name .. "BottomTs", name .. "TopTs", name .. "LeftTs", name .. "RightTs"
    }
    for _, texName in ipairs(texturesToStrip) do
        local tex = _G[texName]
        if tex then if tex.SetTexture then tex:SetTexture(nil) end; tex:Hide() end
    end

    if btn.iceCard then btn.iceCard:Hide(); btn.iceCard = nil end

    if not btn.iceBgTex then
        local bgTex = btn:CreateTexture(nil, "BACKGROUND")
        bgTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        bgTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        bgTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn.iceBgTex = bgTex

        local titleStrip = btn:CreateTexture(nil, "BORDER")
        titleStrip:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        titleStrip:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        titleStrip:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
        titleStrip:SetHeight(20)
        btn.iceTitleStrip = titleStrip
    end

    local label = _G[name .. "Label"]
    local desc = _G[name .. "Description"]
    local reward = _G[name .. "Reward"]
    local dateCompleted = _G[name .. "DateCompleted"]
    local shield = _G[name .. "Shield"]
    local iconBorder = _G[name .. "IconOverlay"]
    local iconTex = _G[name .. "IconTexture"]

    local isEarned = btn.completed or string.find(name, "Summary")

    if isEarned then
        btn.iceBgTex:SetVertexColor(0.06, 0.24, 0.50, 0.96)
        btn.iceTitleStrip:SetGradientAlpha("HORIZONTAL", 0.14, 0.45, 0.85, 0.95, 0.35, 0.75, 1.0, 0.80)
        if label then label:SetTextColor(1.0, 1.0, 1.0) end
        if desc then desc:SetTextColor(0.92, 0.98, 1.0) end
        if dateCompleted then dateCompleted:SetTextColor(0.75, 0.95, 1.0) end
        if iconTex then iconTex:SetDesaturated(false) end
        NS.TintIceTexture(iconBorder, 0.75, 0.95, 1.0)
        if shield then NS.TintFrameRegions(shield, 0.65, 0.92, 1.0) end
    else
        btn.iceBgTex:SetVertexColor(0.02, 0.08, 0.17, 0.92)
        btn.iceTitleStrip:SetGradientAlpha("HORIZONTAL", 0.05, 0.14, 0.28, 0.85, 0.08, 0.20, 0.40, 0.55)
        if label then label:SetTextColor(0.65, 0.82, 0.96) end
        if desc then desc:SetTextColor(0.58, 0.75, 0.90) end
        if iconTex then iconTex:SetDesaturated(true) end
        NS.TintIceTexture(iconBorder, 0.25, 0.48, 0.72)
        if shield then NS.TintFrameRegions(shield, 0.25, 0.45, 0.68) end
    end

    if reward then
        reward:SetTextColor(0.85, 0.98, 1.0)
        reward:SetShadowColor(0, 0, 0, 1)
        reward:SetShadowOffset(1, -1)
    end
end

local function StyleAchievementObjectives()
    for i = 1, 30 do
        local crit = _G["AchievementFrameAchievementsObjectivesCriteria" .. i]
        if crit and crit:IsShown() then
            local nameFs = _G[crit:GetName() .. "Name"]
            if nameFs then
                nameFs:SetTextColor(crit.completed and 0.55 or 0.92, crit.completed and 1.0 or 0.98, crit.completed and 0.80 or 1.0)
            end
        end
        local meta = _G["AchievementFrameAchievementsObjectivesMeta" .. i]
        if meta and meta:IsShown() then
            NS.TintFrameRegions(meta, 0.35, 0.78, 1.0)
            local label = _G[meta:GetName() .. "Label"]
            if label then
                label:SetTextColor(meta.completed and 0.55 or 0.92, meta.completed and 1.0 or 0.98, meta.completed and 0.80 or 1.0)
            end
        end
    end
    LightenAllFontStrings(AchievementFrameAchievementsObjectives)
end

local function StyleAchievementButtons()
    for i = 1, 10 do TintSingleAchievementCard(_G["AchievementFrameAchievementsContainerButton" .. i]) end
    for i = 1, 4 do TintSingleAchievementCard(_G["AchievementFrameSummaryAchievement" .. i]) end
    for i = 1, 20 do
        local catBtn = _G["AchievementFrameCategoriesContainerButton" .. i]
        if catBtn then NS.TintIceTexture(_G[catBtn:GetName() .. "Background"], 0.22, 0.65, 1.0) end
    end

    if AchievementFrameSummaryCategoriesStatusBar then
        AchievementFrameSummaryCategoriesStatusBar:SetStatusBarColor(0.25, 0.75, 1.0)
        NS.TintFrameRegions(AchievementFrameSummaryCategoriesStatusBar, 0.40, 0.82, 1.0)
        local fillBar = _G["AchievementFrameSummaryCategoriesStatusBarFillBar"]
        if fillBar then fillBar:SetTexture(nil) end
    end
    for i = 1, 8 do
        local bar = _G["AchievementFrameSummaryCategoriesCategory" .. i]
        if bar then
            bar:SetStatusBarColor(0.25, 0.75, 1.0)
            NS.TintFrameRegions(bar, 0.40, 0.82, 1.0)
        end
    end
    StyleAchievementObjectives()
end

local function StyleAchievementUI()
    if styled or not AchievementFrame then return end
    styled = true

    local texturesToHide = {
        AchievementFrameBackground, AchievementFrameWaterMark, AchievementFrameWoodBorder,
        AchievementFrameMetalBorderLeft, AchievementFrameMetalBorderRight,
        AchievementFrameMetalBorderBottom, AchievementFrameMetalBorderTop,
        AchievementFrameMetalBorderTopLeft, AchievementFrameMetalBorderTopRight,
        AchievementFrameMetalBorderBottomLeft, AchievementFrameMetalBorderBottomRight
    }
    for _, tex in ipairs(texturesToHide) do
        if tex then if tex.SetTexture then tex:SetTexture(nil) end; tex:Hide() end
    end
    if AchievementFrameMetalBorder then
        NS.CleanFrameTextures(AchievementFrameMetalBorder)
        AchievementFrameMetalBorder:Hide()
    end

    NS.CreateMainWindowBG(AchievementFrame, "ModernAchievementMainBG", {
        left = -6, top = 12, right = 6, bottom = -6, alpha = 0.96, glowHeight = 54
    })

    if AchievementFrameHeader then
        NS.CleanFrameTextures(AchievementFrameHeader)
        local headerPlate = CreateFrame("Frame", "ModernAchievementHeaderPlate", AchievementFrameHeader)
        headerPlate:SetFrameLevel(AchievementFrameHeader:GetFrameLevel() + 2)
        headerPlate:SetSize(230, 34)
        headerPlate:SetPoint("TOPLEFT", AchievementFrame, "TOPLEFT", 185, 8)
        NS.ApplyIceBackdrop(headerPlate, 0.96, 0.05, 0.18, 0.34)

        if AchievementFrameHeaderTitle then
            AchievementFrameHeaderTitle:SetParent(headerPlate)
            AchievementFrameHeaderTitle:ClearAllPoints()
            AchievementFrameHeaderTitle:SetPoint("TOP", headerPlate, "TOP", 0, -4)
            AchievementFrameHeaderTitle:SetTextColor(0.80, 0.95, 1.0)
        end
        if AchievementFrameHeaderPoints then
            AchievementFrameHeaderPoints:SetParent(headerPlate)
            AchievementFrameHeaderPoints:ClearAllPoints()
            AchievementFrameHeaderPoints:SetPoint("BOTTOM", headerPlate, "BOTTOM", 0, 4)
            AchievementFrameHeaderPoints:SetTextColor(1.0, 1.0, 1.0)
        end
    end

    if AchievementFrameFilterDropDown then
        AchievementFrameFilterDropDown:ClearAllPoints()
        AchievementFrameFilterDropDown:SetPoint("TOPRIGHT", AchievementFrame, "TOPRIGHT", -36, -6)
        NS.TintFrameRegions(AchievementFrameFilterDropDown, 0.35, 0.78, 1.0)
    end
    if AchievementFrameCloseButton then
        AchievementFrameCloseButton:ClearAllPoints()
        AchievementFrameCloseButton:SetPoint("TOPRIGHT", AchievementFrame, "TOPRIGHT", 2, 8)
    end

    local subFrames = {
        AchievementFrameCategories, AchievementFrameCategoriesContainer,
        AchievementFrameAchievements, AchievementFrameAchievementsContainer,
        AchievementFrameStats, AchievementFrameStatsContainer,
        AchievementFrameSummary, AchievementFrameSummaryAchievements, AchievementFrameComparison
    }
    for _, sf in ipairs(subFrames) do
        if sf then NS.CleanFrameTextures(sf); NS.ApplyIceBackdrop(sf, 0.65) end
    end

    for _, bg in ipairs({ AchievementFrameCategoriesContainerBackground, AchievementFrameAchievementsContainerBackground, AchievementFrameStatsContainerBackground, AchievementFrameSummaryBackground }) do
        if bg then if bg.SetTexture then bg:SetTexture(nil) end; bg:Hide() end
    end

    NS.TintButtons({ AchievementFrameSummaryAchievementsHeader, AchievementFrameSummaryCategoriesHeader }, 0.35, 0.78, 1.0)
    NS.StyleTabs("AchievementFrameTab", 3, 0.92)
    NS.TintButtons({ AchievementFrameAchievementsContainerScrollBar, AchievementFrameCategoriesContainerScrollBar }, 0.35, 0.78, 1.0)

    if AchievementButton_DisplayAchievement then hooksecurefunc("AchievementButton_DisplayAchievement", StyleAchievementButtons) end
    if AchievementButton_DisplayObjectives then hooksecurefunc("AchievementButton_DisplayObjectives", StyleAchievementObjectives) end
    if AchievementFrameCategories_Update then hooksecurefunc("AchievementFrameCategories_Update", StyleAchievementButtons) end
    if AchievementFrameAchievements_Update then hooksecurefunc("AchievementFrameAchievements_Update", StyleAchievementButtons) end
    if AchievementFrameSummary_Update then hooksecurefunc("AchievementFrameSummary_Update", StyleAchievementButtons) end

    StyleAchievementButtons()
end

function NS.InitAchievementsTheme()
    NS.RegisterTheme("Blizzard_AchievementUI", StyleAchievementUI)
end
