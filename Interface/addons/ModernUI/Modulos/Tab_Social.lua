local addonName, NS = ...

function NS.InitSocialTheme()
    if not FriendsFrame then return end

    NS.CreateMainWindowBG(FriendsFrame, "ModernSocialMainBG", {
        portraits = { FriendsFramePortrait, FriendsFrameIcon },
        closeBtn = FriendsFrameCloseButton,
        titles = { FriendsFrameTitleText }
    })

    local subFrames = {
        FriendsListFrame, IgnoreListFrame, WhoFrame,
        ChannelFrame, RaidFrame, RaidInfoFrame
    }
    for _, sf in ipairs(subFrames) do
        NS.CleanFrameTextures(sf)
    end

    local innerBoxes = {
        FriendsFrameFriendsScrollFrame, FriendsFrameIgnoreScrollFrame, WhoListScrollFrame,
        ChannelListScrollFrame, ChannelRosterScrollFrame
    }
    for _, box in ipairs(innerBoxes) do
        NS.StyleScrollFrameBox(box, 0.55)
    end

    NS.StyleTabs("FriendsFrameTab", 5, 0.90)
    NS.StyleTabs("FriendsTabHeaderTab", 2, 0.88)

    local function FitSocialBottomTabs()
        local bg = _G["ModernSocialMainBG"] or FriendsFrame
        if not bg then return end

        local visibleTabs = {}
        for i = 1, 5 do
            local tab = _G["FriendsFrameTab" .. i]
            if tab and tab:IsShown() then
                table.insert(visibleTabs, tab)
            end
        end

        local count = #visibleTabs
        if count == 0 then return end

        local marginLeft = 6
        local marginRight = 6
        local spacing = 2
        local totalAvailable = (bg:GetWidth() or 368) - marginLeft - marginRight - (spacing * (count - 1))
        local tabWidth = math.floor(totalAvailable / count)

        for idx, tab in ipairs(visibleTabs) do
            tab:ClearAllPoints()
            if PanelTemplates_TabResize then
                PanelTemplates_TabResize(tab, 0, nil)
            end
            tab:SetWidth(tabWidth)

            local fs = tab:GetFontString() or _G[tab:GetName() .. "Text"]
            if fs then
                fs:SetFontObject(GameFontNormalSmall)
                local fontPath, fontSize, fontFlags = fs:GetFont()
                if fontPath and fontSize then
                    fs:SetFont(fontPath, math.max(9, fontSize - 1), fontFlags)
                end
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", tab, "LEFT", 2, 0)
                fs:SetPoint("RIGHT", tab, "RIGHT", -2, 0)
                fs:SetJustifyH("CENTER")
            end

            if idx == 1 then
                tab:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", marginLeft, 2)
            else
                tab:SetPoint("LEFT", visibleTabs[idx - 1], "RIGHT", spacing, 0)
            end
        end
    end

    FitSocialBottomTabs()
    FriendsFrame:HookScript("OnShow", FitSocialBottomTabs)
    if FriendsFrame_Update then
        hooksecurefunc("FriendsFrame_Update", FitSocialBottomTabs)
    end

    NS.TintButtons({
        FriendsFrameAddFriendButton, FriendsFrameSendMessageButton, FriendsFrameIgnorePlayerButton,
        FriendsFrameUnsquelchButton, WhoFrameWhoButton, WhoFrameAddFriendButton, WhoFrameGroupInviteButton,
        ChannelFrameNewButton, RaidFrameConvertToRaidButton, RaidFrameRaidInfoButton, WhoFrameDropDown
    })

    NS.StyleEditBox(WhoFrameEditBox)

    if RaidInfoFrame then
        NS.ApplyIceBackdrop(RaidInfoFrame, 0.96)
        NS.AddTopGlow(RaidInfoFrame, 30)
    end
end
