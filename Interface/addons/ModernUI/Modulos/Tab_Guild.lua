local addonName, NS = ...

local function AdjustGuildInfoLayout()
    if not GuildInfoFrameScrollFrame then return end

    local scrollW = GuildInfoFrameScrollFrame:GetWidth()
    local textW = (scrollW and scrollW > 40) and (scrollW - 20) or 264

    if GuildInfoTextBackground then
        NS.CleanFrameTextures(GuildInfoTextBackground)
        if GuildInfoTextBackground.SetBackdrop then
            GuildInfoTextBackground:SetBackdrop(nil)
        end
        GuildInfoTextBackground:ClearAllPoints()
        GuildInfoTextBackground:SetAllPoints(GuildInfoFrameScrollFrame)
    end

    if GuildInfoEditBox then
        GuildInfoEditBox:SetWidth(textW)
        if GuildInfoEditBox.SetTextInsets then
            GuildInfoEditBox:SetTextInsets(4, 4, 4, 4)
        end
    end

    if GuildInfoText then
        GuildInfoText:SetWidth(textW)
    end

    if GuildInfoFrameScrollFrame.UpdateScrollChildRect then
        GuildInfoFrameScrollFrame:UpdateScrollChildRect()
    end
end

local function UpdateGuildOnlineCounter(infoSummary)
    if not infoSummary then return end

    local total = GetNumGuildMembers() or 0
    local online = 0

    for i = 1, total do
        local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            online = online + 1
        end
    end

    if total > 0 then
        infoSummary:SetText(string.format("|cff73d2ffMiembros:|r |cffffffff%d|r total  (|cff4ade80%d conectados|r)", total, online))
    else
        infoSummary:SetText("|cff73d2ffEstado:|r |cff4ade80Cargando lista...|r")
    end
end

function NS.InitGuildTheme()
    if not FriendsFrame or not GuildFrame or NS.GuildSideFrame then return end

    NS.CleanFrameTextures(GuildFrame)
    NS.StyleScrollFrameBox(GuildListScrollFrame, 0.55)
    NS.TintButtons({
        GuildFrameControlButton, GuildFrameAddMemberButton, GuildFrameGuildInformationButton
    })

    local anchorTarget = _G["ModernSocialMainBG"] or FriendsFrame
    local sideGuild = CreateFrame("Frame", "ModernGuildSideFrame", GuildFrame)
    sideGuild:SetWidth(350)
    sideGuild:SetFrameLevel(anchorTarget:GetFrameLevel())
    sideGuild:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", -4, 0)
    sideGuild:SetPoint("BOTTOMLEFT", anchorTarget, "BOTTOMRIGHT", -4, 0)

    NS.ApplyIceBackdrop(sideGuild, 0.95, 0.05, 0.14, 0.25, 16, 4)
    NS.AddTopGlow(sideGuild, 48)
    NS.GuildSideFrame = sideGuild

    local sideTitle = sideGuild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sideTitle:SetPoint("TOP", sideGuild, "TOP", 0, -14)
    sideTitle:SetText("|cff73d2ffInformación de Hermandad|r")
    sideGuild.title = sideTitle

    local bottomBox = CreateFrame("Frame", nil, sideGuild)
    bottomBox:SetHeight(38)
    bottomBox:SetPoint("BOTTOMLEFT", sideGuild, "BOTTOMLEFT", 12, 12)
    bottomBox:SetPoint("BOTTOMRIGHT", sideGuild, "BOTTOMRIGHT", -12, 12)
    NS.ApplyIceBackdrop(bottomBox, 0.90, 0.02, 0.08, 0.16, 12, 3)

    local infoSummary = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoSummary:SetPoint("LEFT", bottomBox, "LEFT", 10, 0)
    infoSummary:SetText("|cff73d2ffEstado:|r |cff4ade80Listo|r")
    sideGuild.infoSummary = infoSummary

    if GuildInfoFrame then
        NS.CleanFrameTextures(GuildInfoFrame)
        if GuildInfoFrame.SetBackdrop then
            GuildInfoFrame:SetBackdrop(nil)
        end
        GuildInfoFrame:SetParent(sideGuild)
        GuildInfoFrame:ClearAllPoints()
        GuildInfoFrame:SetPoint("TOPLEFT", sideGuild, "TOPLEFT", 12, -36)
        GuildInfoFrame:SetPoint("BOTTOMRIGHT", sideGuild, "BOTTOMRIGHT", -12, 56)

        if GuildInfoCloseButton then
            GuildInfoCloseButton:Hide()
        end

        for _, region in ipairs({ GuildInfoFrame:GetRegions() }) do
            if region:IsObjectType("FontString") then
                region:Hide()
            end
        end

        local textBoxContainer = CreateFrame("Frame", nil, GuildInfoFrame)
        textBoxContainer:SetPoint("TOPLEFT", GuildInfoFrame, "TOPLEFT", 2, -2)
        textBoxContainer:SetPoint("BOTTOMRIGHT", GuildInfoFrame, "BOTTOMRIGHT", -2, 34)
        NS.ApplyIceBackdrop(textBoxContainer, 0.55)

        if GuildInfoFrameScrollFrame then
            NS.StyleScrollFrameBox(GuildInfoFrameScrollFrame, nil)
            GuildInfoFrameScrollFrame:ClearAllPoints()
            GuildInfoFrameScrollFrame:SetPoint("TOPLEFT", textBoxContainer, "TOPLEFT", 12, -12)
            GuildInfoFrameScrollFrame:SetPoint("BOTTOMRIGHT", textBoxContainer, "BOTTOMRIGHT", -26, 12)
            GuildInfoFrameScrollFrame:HookScript("OnSizeChanged", AdjustGuildInfoLayout)
        end

        AdjustGuildInfoLayout()

        if GuildInfoSaveButton then
            GuildInfoSaveButton:ClearAllPoints()
            GuildInfoSaveButton:SetPoint("BOTTOMLEFT", GuildInfoFrame, "BOTTOMLEFT", 2, 2)
        end
        if GuildInfoCancelButton then
            GuildInfoCancelButton:ClearAllPoints()
            GuildInfoCancelButton:SetPoint("LEFT", GuildInfoSaveButton, "RIGHT", 6, 0)
        end
        if GuildInfoGuildEventButton then
            GuildInfoGuildEventButton:ClearAllPoints()
            GuildInfoGuildEventButton:SetPoint("BOTTOMRIGHT", GuildInfoFrame, "BOTTOMRIGHT", -2, 2)
        end

        NS.TintButtons({ GuildInfoSaveButton, GuildInfoCancelButton, GuildInfoGuildEventButton })
        GuildInfoFrame:HookScript("OnShow", AdjustGuildInfoLayout)
    end

    if NS.InitGuildDetailTheme then
        NS.InitGuildDetailTheme(sideGuild, sideTitle)
    end

    if NS.InitGuildControlTheme then
        NS.InitGuildControlTheme(sideGuild, sideTitle, bottomBox)
    end

    -- Escucha cambios en el roster para mantener actualizado el contador de conectados
    sideGuild:RegisterEvent("GUILD_ROSTER_UPDATE")
    sideGuild:SetScript("OnEvent", function(_, event)
        if event == "GUILD_ROSTER_UPDATE" and GuildFrame:IsShown() then
            UpdateGuildOnlineCounter(infoSummary)
        end
    end)

    GuildFrame:HookScript("OnShow", function()
        sideGuild:Show()
        if GuildControlPopupFrame and GuildControlPopupFrame:IsShown() then
            sideTitle:SetText("|cff73d2ffControl de Hermandad|r")
            bottomBox:Hide()
            if GuildInfoFrame then GuildInfoFrame:Hide() end
        elseif GuildMemberDetailFrame and GuildMemberDetailFrame:IsShown() then
            sideTitle:SetText("|cff73d2ffDetalles del Miembro|r")
            bottomBox:Show()
            if NS.UpdateGuildMemberDetailText then NS.UpdateGuildMemberDetailText() end
            if GuildInfoFrame then GuildInfoFrame:Hide() end
        else
            sideTitle:SetText("|cff73d2ffInformación de Hermandad|r")
            bottomBox:Show()
            if GuildInfoFrame then
                GuildInfoFrame:Show()
                AdjustGuildInfoLayout()
            end
        end

        if GuildRoster then GuildRoster() end
        UpdateGuildOnlineCounter(infoSummary)
    end)

    GuildFrame:HookScript("OnHide", function()
        sideGuild:Hide()
    end)
end
