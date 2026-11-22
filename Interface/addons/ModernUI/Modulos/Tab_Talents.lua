local addonName, NS = ...
local styled = false

local function CreateUnspentTalentsAlert(anchorFrame)
    if not PlayerTalentFrame or PlayerTalentFrame.unspentAlertBox then return end

    local alertBox = CreateFrame("Frame", "ModernTalentUnspentAlert", PlayerTalentFrame)
    alertBox:SetSize(112, 130)
    alertBox:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, -155)
    NS.ApplyIceBackdrop(alertBox, 0.95, 0.22, 0.03, 0.03)
    alertBox:SetBackdropBorderColor(1.0, 0.20, 0.20, 1.0)

    local alertText = alertBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    alertText:SetPoint("CENTER", alertBox, "CENTER", 0, 0)
    alertText:SetJustifyH("CENTER")
    alertText:SetTextColor(1.0, 0.22, 0.22)
    alertText:SetShadowColor(0, 0, 0, 1)
    alertText:SetShadowOffset(1, -1)
    alertBox.text = alertText

    alertBox:Hide()
    PlayerTalentFrame.unspentAlertBox = alertBox
end

local function UpdateUnspentTalentsAlert()
    if not PlayerTalentFrame or not PlayerTalentFrame.unspentAlertBox then return end
    local alertBox = PlayerTalentFrame.unspentAlertBox
    local isPet = PlayerTalentFrame.pet
    local activeGroup = GetActiveTalentGroup(false, isPet)
    local unspent = GetUnspentTalentPoints(false, isPet, activeGroup) or 0

    if unspent > 0 then
        alertBox.text:SetText(string.format("%d\nPUNTOS DE\nTALENTOS\nSIN\nGASTAR", unspent))
        alertBox:Show()
    else
        alertBox:Hide()
    end
end

local function StyleTalentUI()
    if styled or not PlayerTalentFrame then return end
    styled = true

    local talentBg = NS.CreateMainWindowBG(PlayerTalentFrame, "ModernTalentMainBG", {
        portraits = { PlayerTalentFramePortrait },
        closeBtn = PlayerTalentFrameCloseButton,
        titles = { PlayerTalentFrameTitleText }
    })

    CreateUnspentTalentsAlert(talentBg)

    if PlayerTalentFrameStatusBar then
        PlayerTalentFrameStatusBar:SetStatusBarColor(0.25, 0.75, 1.0)
        NS.TintFrameRegions(PlayerTalentFrameStatusBar)
    end
    NS.CleanFrameTextures(PlayerTalentFramePointsBar)
    NS.CleanFrameTextures(GlyphFrame)

    NS.TintButtons({ PlayerTalentFrameLearnButton, PlayerTalentFrameResetButton, PlayerTalentFrameActivateButton })
    NS.StyleScrollFrameBox(PlayerTalentFrameScrollFrame)
    NS.StyleTabs("PlayerTalentFrameTab", 3, 0.90)

    for i = 1, 4 do
        NS.TintFrameRegions(_G["PlayerSpecTab" .. i])
    end

    if PlayerTalentFrame_Update then
        hooksecurefunc("PlayerTalentFrame_Update", UpdateUnspentTalentsAlert)
    end
    PlayerTalentFrame:HookScript("OnShow", UpdateUnspentTalentsAlert)
    PlayerTalentFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    PlayerTalentFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    PlayerTalentFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    PlayerTalentFrame:HookScript("OnEvent", UpdateUnspentTalentsAlert)

    UpdateUnspentTalentsAlert()
end

function NS.InitTalentsTheme()
    NS.RegisterTheme("Blizzard_TalentUI", StyleTalentUI)
end
