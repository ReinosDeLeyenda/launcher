local addonName, NS = ...

local function RepaintGossipTexts()
    if GossipFrameNpcNameText then GossipFrameNpcNameText:SetTextColor(0.75, 0.94, 1.0) end
    if GossipGreetingText then GossipGreetingText:SetTextColor(0.92, 0.98, 1.0) end
    for i = 1, NUMGOSSIPBUTTONS or 32 do
        local btn = _G["GossipTitleButton" .. i]
        if btn and btn:IsShown() and btn:GetFontString() then
            btn:GetFontString():SetTextColor(0.65, 0.90, 1.0)
        end
    end
end

local function RepaintQuestDialogTexts()
    if QuestFrameNpcNameText then QuestFrameNpcNameText:SetTextColor(0.75, 0.94, 1.0) end

    local headers = {
        QuestTitleText, QuestProgressTitleText, QuestRewardTitleText,
        QuestInfoTitleHeader, QuestInfoDescriptionHeader, QuestInfoObjectivesHeader,
        QuestInfoRewardsHeader, QuestInfoSpecialTitle
    }
    for _, fs in ipairs(headers) do
        if fs and fs.SetTextColor then fs:SetTextColor(0.45, 0.88, 1.0) end
    end

    local bodyTexts = {
        QuestDescription, QuestObjectiveText, QuestProgressText, QuestProgressRequiredItemsText,
        QuestProgressRequiredMoneyText, QuestRewardText, QuestRewardItemChooseText,
        QuestRewardItemReceiveText, QuestRewardSpellLearnText, QuestInfoObjectivesText,
        QuestInfoDescriptionText, QuestInfoRewardText, QuestInfoItemChooseText,
        QuestInfoItemReceiveText, QuestInfoSpellLearnText, QuestInfoRequiredMoneyText, QuestInfoGroupSize
    }
    for _, fs in ipairs(bodyTexts) do
        if fs and fs.SetTextColor then fs:SetTextColor(0.92, 0.98, 1.0) end
    end

    for i = 1, 10 do
        local qBtn = _G["QuestTitleButton" .. i]
        if qBtn and qBtn:IsShown() and qBtn:GetFontString() then qBtn:GetFontString():SetTextColor(0.65, 0.90, 1.0) end
        for _, prefix in ipairs({ "QuestRewardItem", "QuestProgressItem" }) do
            local itemFs = _G[prefix .. i .. "Name"]
            if itemFs and itemFs:IsShown() then itemFs:SetTextColor(0.95, 0.99, 1.0) end
        end
    end
end

function NS.InitDialogsTheme()
    if GossipFrame then
        NS.CreateMainWindowBG(GossipFrame, "ModernGossipMainBG", {
            portraits = { GossipFramePortrait },
            closeBtn = GossipFrameCloseButton
        })
        NS.CleanFrameTextures(GossipFrameGreetingPanel)
        NS.StyleScrollFrameBox(GossipGreetingScrollFrame, 0.65)
        NS.TintFrameRegions(GossipFrameGreetingGoodbyeButton)

        if GossipFrameUpdate then hooksecurefunc("GossipFrameUpdate", RepaintGossipTexts) end
        GossipFrame:HookScript("OnShow", RepaintGossipTexts)
    end

    if QuestFrame then
        NS.CreateMainWindowBG(QuestFrame, "ModernQuestDialogMainBG", {
            portraits = { QuestFramePortrait },
            closeBtn = QuestFrameCloseButton
        })
        for _, p in ipairs({ QuestFrameGreetingPanel, QuestFrameDetailPanel, QuestFrameProgressPanel, QuestFrameRewardPanel }) do
            NS.CleanFrameTextures(p)
        end
        for _, sc in ipairs({ QuestGreetingScrollFrame, QuestDetailScrollFrame, QuestProgressScrollFrame, QuestRewardScrollFrame }) do
            NS.StyleScrollFrameBox(sc, 0.65)
        end
        NS.TintButtons({
            QuestFrameAcceptButton, QuestFrameDeclineButton, QuestFrameCompleteButton,
            QuestFrameGoodbyeButton, QuestFrameCompleteQuestButton, QuestFrameCancelButton,
            QuestFrameGreetingGoodbyeButton
        })

        if QuestInfo_Display then hooksecurefunc("QuestInfo_Display", RepaintQuestDialogTexts) end
        if QuestFrameProgressItems_Update then hooksecurefunc("QuestFrameProgressItems_Update", RepaintQuestDialogTexts) end
        if QuestFrameGreetingPanel_OnShow then hooksecurefunc("QuestFrameGreetingPanel_OnShow", RepaintQuestDialogTexts) end
        QuestFrame:HookScript("OnShow", RepaintQuestDialogTexts)
    end
end
