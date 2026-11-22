local addonName, NS = ...

function NS.InitReputationTab()
    if not ReputationFrame then return end

    local function StyleReputation()
        NS.CleanFrameTextures(ReputationFrame)
        if ReputationListScrollFrame then
            NS.StyleScrollFrameBox(ReputationListScrollFrame)
        end
        if ReputationDetailFrame then
            NS.CleanFrameTextures(ReputationDetailFrame)
            NS.ApplyIceBackdrop(ReputationDetailFrame, 0.95)
            NS.AddTopGlow(ReputationDetailFrame, 36)
            if ReputationDetailCloseButton then
                ReputationDetailCloseButton:ClearAllPoints()
                ReputationDetailCloseButton:SetPoint("TOPRIGHT", ReputationDetailFrame, "TOPRIGHT", -2, -2)
            end
        end
    end

    StyleReputation()
    ReputationFrame:HookScript("OnShow", StyleReputation)
end
