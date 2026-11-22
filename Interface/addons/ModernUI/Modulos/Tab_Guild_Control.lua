local addonName, NS = ...

local function FindGuildControlButtons()
    local acceptBtn = _G["GuildControlPopupAcceptButton"] or _G["GuildControlPopupFrameAcceptButton"]
    local cancelBtn = _G["GuildControlPopupCancelButton"] or _G["GuildControlPopupFrameCancelButton"]

    if not acceptBtn or not cancelBtn then
        for _, child in ipairs({ GuildControlPopupFrame:GetChildren() }) do
            if child:IsObjectType("Button") and child.GetText then
                local txt = child:GetText() or ""
                if not acceptBtn and (txt == ACCEPT or txt == "Accept" or txt == "Aceptar") then
                    acceptBtn = child
                elseif not cancelBtn and (txt == CANCEL or txt == "Cancel" or txt == "Cancelar") then
                    cancelBtn = child
                end
            end
        end
    end

    return acceptBtn, cancelBtn
end

local function FindGoldEditBox()
    return _G["GuildControlPopupFrameWithdrawGoldEditBox"]
        or _G["GuildControlWithdrawGoldEditBox"]
        or _G["GuildControlPopupFrameGoldEditBox"]
end

function NS.InitGuildControlTheme(sideGuild, sideTitle, bottomBox)
    if not GuildControlPopupFrame or not sideGuild then return end

    NS.CleanFrameTextures(GuildControlPopupFrame)
    if GuildControlPopupFrame.SetBackdrop then
        GuildControlPopupFrame:SetBackdrop(nil)
    end

    GuildControlPopupFrame:SetParent(sideGuild)
    GuildControlPopupFrame:SetFrameLevel(sideGuild:GetFrameLevel() + 8)
    GuildControlPopupFrame:ClearAllPoints()
    GuildControlPopupFrame:SetPoint("TOPLEFT", sideGuild, "TOPLEFT", 6, -6)
    GuildControlPopupFrame:SetPoint("BOTTOMRIGHT", sideGuild, "BOTTOMRIGHT", -6, 6)

    -- Localizar etiqueta "Rank Label:"
    local rankLabelFS
    for _, region in ipairs({ GuildControlPopupFrame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local txt = region:GetText() or ""
            if string.find(txt, "Select") or string.find(txt, "Seleccion") then
                region:ClearAllPoints()
                region:SetPoint("TOP", sideGuild, "TOP", 0, -14)
                region:SetJustifyH("CENTER")
                if GuildControlPopupFrameDropDown then
                    GuildControlPopupFrameDropDown:ClearAllPoints()
                    GuildControlPopupFrameDropDown:SetPoint("TOP", region, "BOTTOM", -16, -6)
                end
            elseif string.find(txt, "Rank Label") or string.find(txt, "Etiqueta") then
                rankLabelFS = region
            elseif string.find(txt, "Allow") or string.find(txt, "Permitir") then
                region:ClearAllPoints()
                region:SetPoint("TOP", sideGuild, "TOP", 0, -104)
                region:SetJustifyH("CENTER")
            end
        end
    end

    if not rankLabelFS and GuildControlPopupFrameEditBox then
        for _, region in ipairs({ GuildControlPopupFrameEditBox:GetRegions() }) do
            if region:IsObjectType("FontString") then
                local txt = region:GetText() or ""
                if string.find(txt, "Rank") or string.find(txt, "Label") or string.find(txt, "Etiqueta") then
                    rankLabelFS = region
                    break
                end
            end
        end
    end

    -- Alinear "Rank Label:" a la izquierda y mover el TextBox a su derecha
    if GuildControlPopupFrameEditBox then
        NS.StyleEditBox(GuildControlPopupFrameEditBox)
        GuildControlPopupFrameEditBox:ClearAllPoints()
        GuildControlPopupFrameEditBox:SetSize(215, 22)
        if GuildControlPopupFrameEditBox.SetTextInsets then
            GuildControlPopupFrameEditBox:SetTextInsets(8, 8, 0, 0)
        end

        if rankLabelFS then
            rankLabelFS:ClearAllPoints()
            rankLabelFS:SetPoint("TOPLEFT", sideGuild, "TOPLEFT", 20, -76)
            rankLabelFS:SetJustifyH("LEFT")
            GuildControlPopupFrameEditBox:SetPoint("LEFT", rankLabelFS, "RIGHT", 10, 0)
        else
            GuildControlPopupFrameEditBox:SetPoint("TOPLEFT", sideGuild, "TOPLEFT", 105, -72)
        end
    end

    local acceptBtn, cancelBtn = FindGuildControlButtons()

    local function PositionActionButtons()
        acceptBtn, cancelBtn = FindGuildControlButtons()

        if cancelBtn then
            cancelBtn:ClearAllPoints()
            cancelBtn:SetSize(76, 22)
            cancelBtn:SetFrameLevel(GuildControlPopupFrame:GetFrameLevel() + 5)
            cancelBtn:SetPoint("RIGHT", sideGuild, "RIGHT", -14, 0)
            if GuildFrameControlButton then
                cancelBtn:SetPoint("BOTTOM", GuildFrameControlButton, "BOTTOM", 0, 0)
            else
                cancelBtn:SetPoint("BOTTOM", sideGuild, "BOTTOM", 0, 12)
            end
        end

        if acceptBtn and cancelBtn then
            acceptBtn:ClearAllPoints()
            acceptBtn:SetSize(76, 22)
            acceptBtn:SetFrameLevel(GuildControlPopupFrame:GetFrameLevel() + 5)
            acceptBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -6, 0)
        end

        local arrowBtn = _G["GuildFrameGuildListToggleButton"]

        if GuildControlPopupFrameTabPermissions then
            NS.CleanFrameTextures(GuildControlPopupFrameTabPermissions)
            NS.ApplyIceBackdrop(GuildControlPopupFrameTabPermissions, 0.55, 0.03, 0.10, 0.20, 10, 3)
            GuildControlPopupFrameTabPermissions:ClearAllPoints()
            GuildControlPopupFrameTabPermissions:SetPoint("LEFT", sideGuild, "LEFT", 14, 0)
            GuildControlPopupFrameTabPermissions:SetPoint("RIGHT", sideGuild, "RIGHT", -14, 0)

            if arrowBtn and arrowBtn:GetBottom() then
                GuildControlPopupFrameTabPermissions:SetPoint("TOP", arrowBtn, "BOTTOM", 0, -4)
            else
                GuildControlPopupFrameTabPermissions:SetPoint("TOP", sideGuild, "TOP", 0, -372)
            end

            if cancelBtn then
                GuildControlPopupFrameTabPermissions:SetPoint("BOTTOM", cancelBtn, "TOP", 0, 4)
            else
                GuildControlPopupFrameTabPermissions:SetPoint("BOTTOM", sideGuild, "BOTTOM", 0, 38)
            end

            GuildControlPopupFrameTabPermissions:SetFrameLevel(GuildControlPopupFrame:GetFrameLevel() + 1)
        end
    end

    PositionActionButtons()

    if GuildControlPopupFrameCheckbox1 then
        GuildControlPopupFrameCheckbox1:ClearAllPoints()
        GuildControlPopupFrameCheckbox1:SetPoint("TOPLEFT", GuildControlPopupFrame, "TOPLEFT", 18, -120)
    end
    for i = 1, 13 do
        local cb = _G["GuildControlPopupFrameCheckbox" .. i]
        if cb then
            cb:SetScale(0.93)
        end
    end

    if GuildControlPopupFrameDropDown then
        NS.TintFrameRegions(GuildControlPopupFrameDropDown)
    end
    if GuildControlTabStackBox then
        NS.StyleEditBox(GuildControlTabStackBox)
        if GuildControlTabStackBox.SetTextInsets then
            GuildControlTabStackBox:SetTextInsets(8, 8, 0, 0)
        end
    end

    -- Estilizar caja de Max Gold/Day ("Unlimited") con margen interior para que no sobresalga
    local goldBox = FindGoldEditBox()
    if goldBox then
        NS.StyleEditBox(goldBox)
        goldBox:SetWidth(130)
        if goldBox.SetTextInsets then
            goldBox:SetTextInsets(8, 8, 0, 0)
        end
    end

    NS.TintButtons({
        acceptBtn,
        cancelBtn,
        GuildControlPopupFrameAddRankButton,
        GuildControlPopupFrameRemoveRankButton
    })

    local function EnsureValidRankSelection()
        if GuildControlPopupFrameDropDown and UIDropDownMenu_GetSelectedID then
            local selID = UIDropDownMenu_GetSelectedID(GuildControlPopupFrameDropDown)
            if not selID or selID < 1 then
                UIDropDownMenu_SetSelectedID(GuildControlPopupFrameDropDown, 1)
            end
        end
        if GuildControlSetRank and GuildControlGetRank then
            local rank = GuildControlGetRank()
            if not rank or rank < 1 then
                GuildControlSetRank(1)
            end
        end
    end

    if GuildControlPopupframe_Update then
        local origUpdate = GuildControlPopupframe_Update
        GuildControlPopupframe_Update = function(...)
            EnsureValidRankSelection()
            local res = origUpdate(...)
            PositionActionButtons()
            return res
        end
    end

    GuildControlPopupFrame:HookScript("OnShow", function()
        EnsureValidRankSelection()
        PositionActionButtons()
        sideTitle:Hide()
        bottomBox:Hide()
        if GuildInfoFrame then GuildInfoFrame:Hide() end
        if GuildMemberDetailFrame then GuildMemberDetailFrame:Hide() end
    end)

    GuildControlPopupFrame:HookScript("OnHide", function()
        sideTitle:Show()
        if GuildFrame and GuildFrame:IsShown() then
            bottomBox:Show()
        end
        if not (GuildMemberDetailFrame and GuildMemberDetailFrame:IsShown()) then
            sideTitle:SetText("|cff73d2ffInformación de Hermandad|r")
            if GuildFrame and GuildFrame:IsShown() and GuildInfoFrame then
                GuildInfoFrame:Show()
            end
        end
    end)
end
