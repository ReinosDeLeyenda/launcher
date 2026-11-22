local addonName, NS = ...

local function FitSingleNoteBox(bgFrame, editBox, innerW)
    if not bgFrame then return end

    for _, child in ipairs({ bgFrame:GetChildren() }) do
        if child:IsObjectType("Button") or child:IsObjectType("EditBox") then
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 8, -6)
            child:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -8, 6)
            child:SetWidth(innerW)
        end
    end

    for _, region in ipairs({ bgFrame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 8, -6)
            region:SetWidth(innerW)
            region:SetJustifyH("LEFT")
            region:SetJustifyV("TOP")
            region:SetWordWrap(true)
        end
    end

    if editBox then
        NS.CleanFrameTextures(editBox)
        editBox:ClearAllPoints()
        editBox:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 8, -6)
        editBox:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -8, 6)
        editBox:SetWidth(innerW)
        editBox:SetMultiLine(true)
        if editBox.SetTextInsets then
            editBox:SetTextInsets(0, 0, 0, 0)
        end
    end
end

function NS.SetupGuildMemberNotes(btnWidth, innerTextWidth)
    if GuildMemberDetailNoteLabel and GuildMemberDetailOnlineText then
        GuildMemberDetailNoteLabel:ClearAllPoints()
        GuildMemberDetailNoteLabel:SetPoint("TOPLEFT", GuildMemberDetailOnlineText, "BOTTOMLEFT", 0, -10)
        GuildMemberDetailNoteLabel:SetJustifyH("LEFT")
    end

    if GuildMemberNoteBackground and GuildMemberDetailNoteLabel then
        NS.CleanFrameTextures(GuildMemberNoteBackground)
        NS.ApplyIceBackdrop(GuildMemberNoteBackground, 0.55, 0.03, 0.10, 0.20, 10, 3)
        GuildMemberNoteBackground:ClearAllPoints()
        GuildMemberNoteBackground:SetPoint("TOPLEFT", GuildMemberDetailNoteLabel, "BOTTOMLEFT", 0, -4)
        GuildMemberNoteBackground:SetSize(btnWidth, 58)
        FitSingleNoteBox(GuildMemberNoteBackground, GuildMemberNoteEditBox, innerTextWidth)
    end

    if GuildMemberDetailOfficerNoteLabel and GuildMemberNoteBackground then
        GuildMemberDetailOfficerNoteLabel:ClearAllPoints()
        GuildMemberDetailOfficerNoteLabel:SetPoint("TOPLEFT", GuildMemberNoteBackground, "BOTTOMLEFT", 0, -8)
        GuildMemberDetailOfficerNoteLabel:SetJustifyH("LEFT")
    end

    if GuildMemberOfficerNoteBackground and GuildMemberDetailOfficerNoteLabel then
        NS.CleanFrameTextures(GuildMemberOfficerNoteBackground)
        NS.ApplyIceBackdrop(GuildMemberOfficerNoteBackground, 0.55, 0.03, 0.10, 0.20, 10, 3)
        GuildMemberOfficerNoteBackground:ClearAllPoints()
        GuildMemberOfficerNoteBackground:SetPoint("TOPLEFT", GuildMemberDetailOfficerNoteLabel, "BOTTOMLEFT", 0, -4)
        GuildMemberOfficerNoteBackground:SetWidth(btnWidth)
        if GuildMemberRemoveButton then
            GuildMemberOfficerNoteBackground:SetPoint("BOTTOM", GuildMemberRemoveButton, "TOP", 0, 8)
        else
            GuildMemberOfficerNoteBackground:SetHeight(58)
        end
        FitSingleNoteBox(GuildMemberOfficerNoteBackground, GuildMemberOfficerNoteEditBox, innerTextWidth)
    end

    local textPairs = {
        { GuildMemberDetailNoteText, GuildMemberNoteBackground },
        { GuildMemberNoteBackgroundText, GuildMemberNoteBackground },
        { GuildMemberDetailOfficerNoteText, GuildMemberOfficerNoteBackground },
        { GuildMemberOfficerNoteBackgroundText, GuildMemberOfficerNoteBackground },
    }
    for _, pair in ipairs(textPairs) do
        local txt, bg = pair[1], pair[2]
        if txt and bg then
            txt:ClearAllPoints()
            txt:SetPoint("TOPLEFT", bg, "TOPLEFT", 8, -6)
            txt:SetWidth(innerTextWidth)
            txt:SetJustifyH("LEFT")
            txt:SetJustifyV("TOP")
            if txt.SetWordWrap then txt:SetWordWrap(true) end
        end
    end
end
