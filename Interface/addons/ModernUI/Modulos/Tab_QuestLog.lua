local addonName, NS = ...

local function RepaintQuestInfoTexts()
    local headers = {
        QuestLogTitleText, QuestInfoTitleHeader, QuestInfoDescriptionHeader,
        QuestInfoObjectivesHeader, QuestInfoRewardsHeader, QuestInfoSpecialTitle
    }
    for _, fs in ipairs(headers) do
        if fs and fs.SetTextColor then fs:SetTextColor(0.45, 0.88, 1.0) end
    end

    local bodyTexts = {
        QuestInfoObjectivesText, QuestInfoDescriptionText, QuestInfoRewardText,
        QuestInfoItemChooseText, QuestInfoItemReceiveText, QuestInfoSpellLearnText,
        QuestInfoRequiredMoneyText, QuestInfoGroupSize, QuestInfoTimerText, QuestLogQuestCount
    }
    for _, fs in ipairs(bodyTexts) do
        if fs and fs.SetTextColor then fs:SetTextColor(0.92, 0.97, 1.0) end
    end

    for i = 1, 20 do
        local obj = _G["QuestInfoObjective" .. i]
        if obj and obj:IsShown() then
            local r, g, b = obj:GetTextColor()
            if r < 0.35 and g < 0.35 and b < 0.35 then
                obj:SetTextColor(0.90, 0.96, 1.0)
            else
                obj:SetTextColor(0.45, 1.0, 0.55)
            end
        end
    end

    for i = 1, 10 do
        local itemName = _G["QuestInfoItem" .. i .. "Name"]
        if itemName and itemName:IsShown() then itemName:SetTextColor(0.95, 0.98, 1.0) end
    end

    if QuestInfoFrame then
        for _, region in ipairs({ QuestInfoFrame:GetRegions() }) do
            if region:IsObjectType("FontString") then
                local r, g, b = region:GetTextColor()
                if r < 0.35 and g < 0.35 and b < 0.35 then region:SetTextColor(0.92, 0.97, 1.0) end
            end
        end
    end
end

function NS.InitQuestLogTheme()
    if not QuestLogFrame then return end

    NS.CreateMainWindowBG(QuestLogFrame, "ModernQuestLogMainBG", {
        portraits = { QuestLogFramePortrait },
        right = -6, bottom = 8, glowHeight = 42
    })

    if QuestLogListScrollFrame then
        NS.StyleScrollFrameBox(QuestLogListScrollFrame)
        local listBox = CreateFrame("Frame", nil, QuestLogFrame)
        listBox:SetFrameLevel(QuestLogFrame:GetFrameLevel())
        listBox:SetPoint("TOPLEFT", QuestLogListScrollFrame, "TOPLEFT", -6, 6)
        listBox:SetPoint("BOTTOMRIGHT", QuestLogListScrollFrame, "BOTTOMRIGHT", 24, -6)
        NS.ApplyIceBackdrop(listBox, 0.65)
    end

    if QuestLogDetailScrollFrame then
        NS.StyleScrollFrameBox(QuestLogDetailScrollFrame)
        local detailBox = CreateFrame("Frame", nil, QuestLogFrame)
        detailBox:SetFrameLevel(QuestLogFrame:GetFrameLevel())
        detailBox:SetPoint("TOPLEFT", QuestLogDetailScrollFrame, "TOPLEFT", -8, 6)
        detailBox:SetPoint("BOTTOMRIGHT", QuestLogDetailScrollFrame, "BOTTOMRIGHT", 24, -6)
        NS.ApplyIceBackdrop(detailBox, 0.80)
    end

    NS.TintButtons({
        QuestLogFrameAbandonButton, QuestLogFramePushQuestButton, QuestLogFrameTrackButton,
        QuestLogFrameShowMapButton, QuestLogFrameCancelButton, QuestLogFrameCompleteButton
    })

    if QuestLogDetailFrame then
        NS.CreateMainWindowBG(QuestLogDetailFrame, "ModernQuestLogDetailBG", {
            right = -6, bottom = 8, glowHeight = 38
        })
    end

    if QuestInfo_Display then hooksecurefunc("QuestInfo_Display", RepaintQuestInfoTexts) end
    if QuestLog_UpdateQuestDetails then hooksecurefunc("QuestLog_UpdateQuestDetails", RepaintQuestInfoTexts) end
    if QuestLog_Update then hooksecurefunc("QuestLog_Update", RepaintQuestInfoTexts) end
    QuestLogFrame:HookScript("OnShow", RepaintQuestInfoTexts)
    RepaintQuestInfoTexts()
end
