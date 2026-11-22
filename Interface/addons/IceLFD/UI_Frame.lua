local addonName, addon = ...

local PartySideFrame = CreateFrame("Frame", "IceLFD_PartyFrame", LFDParentFrame)
PartySideFrame:SetWidth(345)
PartySideFrame:SetFrameStrata("HIGH")
PartySideFrame:SetPoint("TOPLEFT", LFDParentFrame, "TOPRIGHT", -4, -12)
PartySideFrame:SetPoint("BOTTOMLEFT", LFDParentFrame, "BOTTOMRIGHT", -4, 4)
PartySideFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
PartySideFrame:SetBackdropColor(0.04, 0.14, 0.26, 0.95)
PartySideFrame:SetBackdropBorderColor(addon.ICE_R, addon.ICE_G, addon.ICE_B, 1)
PartySideFrame:Hide()
addon.PartySideFrame = PartySideFrame

local TitleText = PartySideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
TitleText:SetPoint("TOP", 0, -10)
TitleText:SetText("|cff73d2ffGrupo & iLvl|r")

function addon.CreateIceWarnIcon(parent, r, g, b, onEnterFn)
    local btn = CreateFrame("Frame", nil, parent)
    btn:SetSize(22, 22)
    btn:EnableMouse(true)

    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    tex:SetVertexColor(r, g, b)
    btn.tex = tex

    btn:SetScript("OnEnter", onEnterFn)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
    return btn
end
