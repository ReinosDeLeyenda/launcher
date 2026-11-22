local addonName, addon = ...

local PlayerWarnBox = CreateFrame("Frame", "IceLFD_PlayerWarnBox", addon.PartySideFrame)
PlayerWarnBox:SetHeight(44)
PlayerWarnBox:SetPoint("BOTTOMLEFT", addon.PartySideFrame, "BOTTOMLEFT", 10, 10)
PlayerWarnBox:SetPoint("BOTTOMRIGHT", addon.PartySideFrame, "BOTTOMRIGHT", -10, 10)
PlayerWarnBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 12, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
PlayerWarnBox:SetBackdropColor(0.02, 0.08, 0.16, 0.90)
PlayerWarnBox:SetBackdropBorderColor(addon.ICE_R, addon.ICE_G, addon.ICE_B, 0.85)

local playerTitle = PlayerWarnBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
playerTitle:SetPoint("LEFT", PlayerWarnBox, "LEFT", 8, 0)
playerTitle:SetText("|cff73d2ffTus avisos:|r")
addon.playerTitle = playerTitle

local playerOkText = PlayerWarnBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
playerOkText:SetPoint("LEFT", playerTitle, "RIGHT", 6, 0)
playerOkText:SetText("|cff4ade80Todo listo|r")
addon.playerOkText = playerOkText

local function OnMyWarnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.titleText)
    GameTooltip:AddLine(self.reason or "", 1, 1, 1, true)
    GameTooltip:Show()
end

addon.myRoleWarn = addon.CreateIceWarnIcon(PlayerWarnBox, 1.0, 0.85, 0.1, OnMyWarnEnter)
addon.myRoleWarn.titleText = "|cffffd700Rol incompatible en grupo|r"

addon.myTalentWarn = addon.CreateIceWarnIcon(PlayerWarnBox, 1.0, 0.85, 0.1, OnMyWarnEnter)
addon.myTalentWarn.titleText = "|cffffd700Talentos incompletos|r"

addon.myGearWarn = addon.CreateIceWarnIcon(PlayerWarnBox, 1.0, 0.85, 0.1, OnMyWarnEnter)
addon.myGearWarn.titleText = "|cffffd700Equipo de nivel bajo|r"

addon.myLevelWarn = addon.CreateIceWarnIcon(PlayerWarnBox, 1.0, 0.15, 0.15, OnMyWarnEnter)
addon.myLevelWarn.titleText = "|cffff3333Nivel o requisito insuficiente|r"

-- NUEVO: Icono de versión desactualizada (Azul cian)
addon.myVersionWarn = addon.CreateIceWarnIcon(PlayerWarnBox, 0.25, 0.85, 1.0, OnMyWarnEnter)
addon.myVersionWarn.titleText = "|cff66ccffNueva versión disponible|r"

addon.myWarnIcons = { addon.myRoleWarn, addon.myTalentWarn, addon.myGearWarn, addon.myLevelWarn, addon.myVersionWarn }
