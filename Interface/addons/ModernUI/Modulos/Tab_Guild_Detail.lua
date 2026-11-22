local addonName, NS = ...

local function FindPromoteDemoteButtons()
    local prom = _G["GuildMemberDetailPromote"] or _G["GuildMemberDetailPromoteButton"]
    local dem = _G["GuildMemberDetailDemote"] or _G["GuildMemberDetailDemoteButton"]

    if (not prom or not dem) and GuildMemberDetailFrame then
        local smallBtns = {}
        for _, child in ipairs({ GuildMemberDetailFrame:GetChildren() }) do
            if child:IsObjectType("Button") then
                local w, h = child:GetWidth(), child:GetHeight()
                if w and h and w <= 30 and h <= 30 then
                    table.insert(smallBtns, child)
                end
            end
        end
        if #smallBtns >= 2 then
            prom = prom or smallBtns[1]
            dem = dem or smallBtns[2]
        end
    end

    return prom, dem
end

function NS.UpdateGuildMemberDetailText()
    local sel = GetGuildRosterSelection and GetGuildRosterSelection()
    if not sel or sel <= 0 or not GetGuildRosterInfo then return end

    local name, _, _, level, class, _, _, _, _, _, classFileName = GetGuildRosterInfo(sel)
    if GuildMemberDetailName and name then
        GuildMemberDetailName:SetText(name)
    end
    if GuildMemberDetailLevel and level then
        GuildMemberDetailLevel:SetText(string.format("|cffffffffLevel %d|r", level))
    end
    if GuildMemberDetailFrame and GuildMemberDetailFrame.classText then
        local token = classFileName or (class and strupper(class))
        local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if color then
            GuildMemberDetailFrame.classText:SetTextColor(color.r, color.g, color.b)
        else
            GuildMemberDetailFrame.classText:SetTextColor(0.45, 0.82, 1.0)
        end
        GuildMemberDetailFrame.classText:SetText(class or "")
    end

    if GuildMemberDetailFrame and GuildMemberDetailFrame.dungeonPie and NS.UpdateGuildDungeonPie then
        NS.UpdateGuildDungeonPie(GuildMemberDetailFrame.dungeonPie, name)
    end
    if GuildMemberDetailFrame and GuildMemberDetailFrame.raidPie and NS.UpdateGuildRaidPie then
        NS.UpdateGuildRaidPie(GuildMemberDetailFrame.raidPie, name)
    end
end

function NS.InitGuildDetailTheme(sideGuild, sideTitle)
    if not GuildMemberDetailFrame or not sideGuild then return end

    NS.CleanFrameTextures(GuildMemberDetailFrame)
    if GuildMemberDetailFrame.SetBackdrop then
        GuildMemberDetailFrame:SetBackdrop(nil)
    end

    GuildMemberDetailFrame:SetParent(sideGuild)
    GuildMemberDetailFrame:SetFrameLevel(sideGuild:GetFrameLevel() + 5)
    GuildMemberDetailFrame:ClearAllPoints()
    GuildMemberDetailFrame:SetPoint("TOPLEFT", sideGuild, "TOPLEFT", 12, -34)
    GuildMemberDetailFrame:SetPoint("BOTTOMRIGHT", sideGuild, "BOTTOMRIGHT", -12, 54)

    if GuildMemberDetailCloseButton then
        GuildMemberDetailCloseButton:ClearAllPoints()
        GuildMemberDetailCloseButton:SetPoint("TOPRIGHT", sideGuild, "TOPRIGHT", -4, -4)
        GuildMemberDetailCloseButton:Show()
    end

    local btnWidth = 136
    local innerTextWidth = btnWidth - 16

    if GuildMemberRemoveButton then
        GuildMemberRemoveButton:ClearAllPoints()
        GuildMemberRemoveButton:SetSize(btnWidth, 22)
        GuildMemberRemoveButton:SetPoint("BOTTOMLEFT", GuildMemberDetailFrame, "BOTTOMLEFT", 6, 4)
    end
    if GuildMemberGroupInviteButton then
        GuildMemberGroupInviteButton:ClearAllPoints()
        GuildMemberGroupInviteButton:SetSize(btnWidth, 22)
        GuildMemberGroupInviteButton:SetPoint("BOTTOMRIGHT", GuildMemberDetailFrame, "BOTTOMRIGHT", -6, 4)
    end
    NS.TintButtons({ GuildMemberRemoveButton, GuildMemberGroupInviteButton })

    if GuildMemberDetailName then
        GuildMemberDetailName:ClearAllPoints()
        GuildMemberDetailName:SetPoint("TOPLEFT", GuildMemberDetailFrame, "TOPLEFT", 10, -4)
        GuildMemberDetailName:SetJustifyH("LEFT")
    end

    if not GuildMemberDetailFrame.dungeonPie and NS.CreateGuildDungeonPie then
        local pie = NS.CreateGuildDungeonPie(GuildMemberDetailFrame)
        pie:SetPoint("TOPRIGHT", GuildMemberDetailFrame, "TOPRIGHT", -10, -4)
        GuildMemberDetailFrame.dungeonPie = pie
    end

    if not GuildMemberDetailFrame.raidPie and NS.CreateGuildRaidPie and GuildMemberDetailFrame.dungeonPie then
        local raidPie = NS.CreateGuildRaidPie(GuildMemberDetailFrame)
        raidPie:SetPoint("TOP", GuildMemberDetailFrame.dungeonPie, "BOTTOM", 0, -10)
        GuildMemberDetailFrame.raidPie = raidPie
    end

    if GuildMemberDetailLevel then
        GuildMemberDetailLevel:ClearAllPoints()
        GuildMemberDetailLevel:SetPoint("TOPLEFT", GuildMemberDetailName, "BOTTOMLEFT", 0, -4)
        GuildMemberDetailLevel:SetJustifyH("LEFT")
    end

    if not GuildMemberDetailFrame.classText then
        GuildMemberDetailFrame.classText = GuildMemberDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    GuildMemberDetailFrame.classText:ClearAllPoints()
    GuildMemberDetailFrame.classText:SetPoint("TOPLEFT", GuildMemberDetailLevel, "BOTTOMLEFT", 0, -3)
    GuildMemberDetailFrame.classText:SetJustifyH("LEFT")

    if GuildMemberDetailZoneLabel then
        GuildMemberDetailZoneLabel:ClearAllPoints()
        GuildMemberDetailZoneLabel:SetPoint("TOPLEFT", GuildMemberDetailFrame.classText, "BOTTOMLEFT", 0, -10)
        GuildMemberDetailZoneLabel:SetJustifyH("LEFT")
    end
    if GuildMemberDetailZoneText and GuildMemberDetailZoneLabel then
        GuildMemberDetailZoneText:ClearAllPoints()
        GuildMemberDetailZoneText:SetPoint("TOPLEFT", GuildMemberDetailZoneLabel, "BOTTOMLEFT", 0, -2)
        GuildMemberDetailZoneText:SetWidth(155)
        GuildMemberDetailZoneText:SetJustifyH("LEFT")
    end

    -- Rank: [Flecha Subir] [Flecha Bajar] -> debajo RangoPJ
    if GuildMemberDetailRankLabel and GuildMemberDetailZoneText then
        GuildMemberDetailRankLabel:ClearAllPoints()
        GuildMemberDetailRankLabel:SetPoint("TOPLEFT", GuildMemberDetailZoneText, "BOTTOMLEFT", 0, -8)
        GuildMemberDetailRankLabel:SetJustifyH("LEFT")
    end

    local function PositionRankArrows()
        local promoteBtn, demoteBtn = FindPromoteDemoteButtons()
        if promoteBtn and GuildMemberDetailRankLabel then
            promoteBtn:ClearAllPoints()
            promoteBtn:SetPoint("LEFT", GuildMemberDetailRankLabel, "RIGHT", 6, 0)
        end
        if demoteBtn and promoteBtn then
            demoteBtn:ClearAllPoints()
            demoteBtn:SetPoint("LEFT", promoteBtn, "RIGHT", 2, 0)
        end
        if GuildMemberDetailRankText and GuildMemberDetailRankLabel then
            GuildMemberDetailRankText:ClearAllPoints()
            GuildMemberDetailRankText:SetPoint("TOPLEFT", GuildMemberDetailRankLabel, "BOTTOMLEFT", 0, -4)
            GuildMemberDetailRankText:SetWidth(155)
            GuildMemberDetailRankText:SetJustifyH("LEFT")
        end
    end

    PositionRankArrows()

    if GuildMemberDetailOnlineLabel and GuildMemberDetailRankText then
        GuildMemberDetailOnlineLabel:ClearAllPoints()
        GuildMemberDetailOnlineLabel:SetPoint("TOPLEFT", GuildMemberDetailRankText, "BOTTOMLEFT", 0, -10)
        GuildMemberDetailOnlineLabel:SetJustifyH("LEFT")
    end
    if GuildMemberDetailOnlineText and GuildMemberDetailOnlineLabel then
        GuildMemberDetailOnlineText:ClearAllPoints()
        GuildMemberDetailOnlineText:SetPoint("TOPLEFT", GuildMemberDetailOnlineLabel, "BOTTOMLEFT", 0, -2)
        GuildMemberDetailOnlineText:SetWidth(155)
        GuildMemberDetailOnlineText:SetJustifyH("LEFT")
    end

    if NS.SetupGuildMemberNotes then
        NS.SetupGuildMemberNotes(btnWidth, innerTextWidth)
    end

    if GuildFrame_Update then
        hooksecurefunc("GuildFrame_Update", function()
            if GuildMemberDetailFrame:IsShown() then
                PositionRankArrows()
                NS.UpdateGuildMemberDetailText()
            end
        end)
    end

    if GuildStatus_Update then
        hooksecurefunc("GuildStatus_Update", function()
            if GuildMemberDetailFrame:IsShown() then
                PositionRankArrows()
                NS.UpdateGuildMemberDetailText()
            end
        end)
    end

    GuildMemberDetailFrame:HookScript("OnShow", function()
        sideTitle:SetText("|cff73d2ffDetalles del Miembro|r")
        PositionRankArrows()
        NS.UpdateGuildMemberDetailText()
        if GuildInfoFrame then GuildInfoFrame:Hide() end
        if GuildControlPopupFrame then GuildControlPopupFrame:Hide() end
    end)

    GuildMemberDetailFrame:HookScript("OnHide", function()
        if not (GuildControlPopupFrame and GuildControlPopupFrame:IsShown()) then
            sideTitle:SetText("|cff73d2ffInformación de Hermandad|r")
            if GuildFrame:IsShown() and GuildInfoFrame then
                GuildInfoFrame:Show()
            end
        end
    end)
end
