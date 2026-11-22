local addonName, NS = ...

function NS.InitTokensTab()
    if not TokenFrame then return end

    local function StyleTokens()
        NS.CleanFrameTextures(TokenFrame)
        if TokenFrameContainerScrollBar then
            NS.StyleScrollBar(TokenFrameContainerScrollBar)
        end
        if TokenFramePopup then
            NS.CleanFrameTextures(TokenFramePopup)
            NS.ApplyIceBackdrop(TokenFramePopup, 0.95)
            NS.AddTopGlow(TokenFramePopup, 32)
            if TokenFramePopupCloseButton then
                TokenFramePopupCloseButton:ClearAllPoints()
                TokenFramePopupCloseButton:SetPoint("TOPRIGHT", TokenFramePopup, "TOPRIGHT", -2, -2)
            end
        end
    end

    StyleTokens()
    TokenFrame:HookScript("OnShow", StyleTokens)
end
