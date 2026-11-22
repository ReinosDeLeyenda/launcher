RDL_DE_UI = {}

local selFrame = CreateFrame("Frame", "RDL_DESelectorFrame", RDL_GUI)
selFrame:SetSize(310, 444)
selFrame:SetPoint("TOPLEFT", RDL_GUI, "TOPRIGHT", 8, -44)
selFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
selFrame:SetBackdropColor(0.06, 0.22, 0.38, 0.94)
selFrame:SetBackdropBorderColor(0.55, 0.90, 1.0, 1)
selFrame:Hide()
RDL_DE_UI.selFrame = selFrame

local selGrad = selFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
selGrad:SetPoint("TOPLEFT", 4, -4)
selGrad:SetPoint("BOTTOMRIGHT", -4, 4)
selGrad:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
selGrad:SetGradientAlpha("VERTICAL", 0.04, 0.14, 0.26, 0.2, 0.35, 0.78, 1.0, 0.32)

local title = selFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("|cff9beeffDesencantamiento Masivo|r")

local closeBtn = CreateFrame("Button", nil, selFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() selFrame:Hide() end)

local function MakeCheck(name, x, y, text, color, key)
    local cb = CreateFrame("CheckButton", name, selFrame, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetChecked(RDL_Disenchant.Filters[key])
    local lbl = selFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(color .. text .. "|r")
    cb:SetScript("OnClick", function(self)
        RDL_Disenchant.Filters[key] = self:GetChecked() and true or false
        RDL_Disenchant.RefreshList()
    end)
    return cb
end

MakeCheck("RDL_DE_Green", 12, -34, "Verdes", "|cff1eff00", "green")
MakeCheck("RDL_DE_Blue", 95, -34, "Azules", "|cff0070dd", "blue")
MakeCheck("RDL_DE_Epic", 178, -34, "Epicos", "|cffa335ee", "epic")
MakeCheck("RDL_DE_Bound", 12, -56, "Incluir objetos ligados", "|cffbdeeff", "allowBound")

local lvlLbl = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lvlLbl:SetPoint("TOPLEFT", 16, -84)
lvlLbl:SetText("|cffd4f4ffNivel objeto:|r")

local minBox = CreateFrame("EditBox", "RDL_DE_MinLvl", selFrame, "InputBoxTemplate")
minBox:SetSize(38, 18)
minBox:SetPoint("LEFT", lvlLbl, "RIGHT", 8, 0)
minBox:SetNumeric(true)
minBox:SetAutoFocus(false)
minBox:SetText("1")
minBox:SetScript("OnTextChanged", function(self)
    RDL_Disenchant.Filters.minLvl = tonumber(self:GetText()) or 1
    RDL_Disenchant.RefreshList()
end)

local sepLbl = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sepLbl:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
sepLbl:SetText("|cffd4f4ffa|r")

local maxBox = CreateFrame("EditBox", "RDL_DE_MaxLvl", selFrame, "InputBoxTemplate")
maxBox:SetSize(38, 18)
maxBox:SetPoint("LEFT", sepLbl, "RIGHT", 8, 0)
maxBox:SetNumeric(true)
maxBox:SetAutoFocus(false)
maxBox:SetText("300")
maxBox:SetScript("OnTextChanged", function(self)
    RDL_Disenchant.Filters.maxLvl = tonumber(self:GetText()) or 300
    RDL_Disenchant.RefreshList()
end)

local sortLbl = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sortLbl:SetPoint("TOPLEFT", 16, -112)
sortLbl:SetText("|cffd4f4ffOrdenar:|r")

RDL_DE_UI.sortDrop = CreateFrame("Frame", "RDL_DESortDropDown", selFrame, "UIDropDownMenuTemplate")
RDL_DE_UI.sortDrop:SetPoint("LEFT", sortLbl, "RIGHT", -8, -2)
UIDropDownMenu_SetWidth(RDL_DE_UI.sortDrop, 180)
UIDropDownMenu_SetText(RDL_DE_UI.sortDrop, "Cantidad (Mas a menos)")

RDL_DE_UI.scroll = CreateFrame("ScrollFrame", "RDL_DEScroll", selFrame, "FauxScrollFrameTemplate")
RDL_DE_UI.scroll:SetSize(258, 216)
RDL_DE_UI.scroll:SetPoint("TOPLEFT", 14, -136)

RDL_DE_UI.rows = {}
for i = 1, 9 do
    local b = CreateFrame("Button", nil, selFrame)
    b:SetSize(256, 24)
    b:SetPoint("TOPLEFT", 14, -136 - ((i - 1) * 24))
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 2, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetWidth(224)
    b.text:SetJustifyH("LEFT")
    RDL_DE_UI.rows[i] = b
end

local qtyLabel = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
qtyLabel:SetPoint("BOTTOMLEFT", 16, 44)
qtyLabel:SetText("|cffd4f4ffCantidad a desencantar:|r")

RDL_DE_UI.qtyBox = CreateFrame("EditBox", "RDL_DEQtyBox", selFrame, "InputBoxTemplate")
RDL_DE_UI.qtyBox:SetSize(45, 20)
RDL_DE_UI.qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
RDL_DE_UI.qtyBox:SetNumeric(true)
RDL_DE_UI.qtyBox:SetAutoFocus(false)
RDL_DE_UI.qtyBox:SetText("1")

RDL_DE_UI.startBtn = CreateFrame("Button", nil, selFrame, "UIPanelButtonTemplate")
RDL_DE_UI.startBtn:SetSize(276, 24)
RDL_DE_UI.startBtn:SetPoint("BOTTOM", 0, 12)
RDL_DE_UI.startBtn:SetText("Confirmar y preparar desencantamiento")

local execFrame = CreateFrame("Frame", "RDL_DEExecFrame", UIParent)
execFrame:SetSize(310, 110)
execFrame:SetPoint("TOPLEFT", RDL_GUI, "TOPRIGHT", 8, -44)
execFrame:SetFrameStrata("DIALOG")
execFrame:SetMovable(true)
execFrame:EnableMouse(true)
execFrame:RegisterForDrag("LeftButton")
execFrame:SetScript("OnDragStart", execFrame.StartMoving)
execFrame:SetScript("OnDragStop", execFrame.StopMovingOrSizing)
execFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
execFrame:SetBackdropColor(0.06, 0.22, 0.38, 0.96)
execFrame:SetBackdropBorderColor(0.55, 0.90, 1.0, 1)
execFrame:Hide()
RDL_DE_UI.execFrame = execFrame

local execGrad = execFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
execGrad:SetPoint("TOPLEFT", 4, -4)
execGrad:SetPoint("BOTTOMRIGHT", -4, 4)
execGrad:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
execGrad:SetGradientAlpha("VERTICAL", 0.04, 0.14, 0.26, 0.2, 0.35, 0.78, 1.0, 0.32)

local execTitle = execFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
execTitle:SetPoint("TOP", 0, -12)
execTitle:SetText("|cff9beeffDesencantamiento en curso|r")

RDL_DE_UI.execStatus = execFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RDL_DE_UI.execStatus:SetPoint("TOP", 0, -34)
RDL_DE_UI.execStatus:SetTextColor(0.88, 0.97, 1.0)

RDL_DE_UI.actionBtn = CreateFrame("Button", "RDL_SecureDEButton", execFrame, "UIPanelButtonTemplate, SecureActionButtonTemplate")
RDL_DE_UI.actionBtn:SetSize(196, 26)
RDL_DE_UI.actionBtn:SetPoint("BOTTOMLEFT", 16, 14)
RDL_DE_UI.actionBtn:RegisterForClicks("AnyUp")
RDL_DE_UI.actionBtn:SetAttribute("type", "macro")

RDL_DE_UI.cancelBtn = CreateFrame("Button", nil, execFrame, "UIPanelButtonTemplate")
RDL_DE_UI.cancelBtn:SetSize(74, 26)
RDL_DE_UI.cancelBtn:SetPoint("LEFT", RDL_DE_UI.actionBtn, "RIGHT", 6, 0)
RDL_DE_UI.cancelBtn:SetText("Cancelar")
