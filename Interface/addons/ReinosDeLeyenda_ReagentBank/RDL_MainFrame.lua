RDL_GUI = CreateFrame("Frame", "RDL_MainProfessionFrame", UIParent)
local gui = RDL_GUI
gui:SetSize(560, 495)
gui:SetPoint("CENTER")
gui:SetFrameStrata("HIGH")
gui:SetMovable(true)
gui:EnableMouse(true)
gui:RegisterForDrag("LeftButton")
gui:SetScript("OnDragStart", gui.StartMoving)
gui:SetScript("OnDragStop", gui.StopMovingOrSizing)
gui:Hide()
tinsert(UISpecialFrames, "RDL_MainProfessionFrame")

-- Textura tintable real para que el color azul hielo se vea vivo
gui:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
gui:SetBackdropColor(0.06, 0.22, 0.38, 0.94)
gui:SetBackdropBorderColor(0.55, 0.90, 1.0, 1)

-- Brillo/degradado superior estilo cristal de hielo
local frostGrad = gui:CreateTexture(nil, "BACKGROUND", nil, 1)
frostGrad:SetPoint("TOPLEFT", 4, -4)
frostGrad:SetPoint("BOTTOMRIGHT", -4, 4)
frostGrad:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
frostGrad:SetGradientAlpha("VERTICAL", 0.04, 0.14, 0.26, 0.2, 0.35, 0.78, 1.0, 0.32)

local title = gui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 18, -14)
title:SetText("|cff9beeffReinos de leyenda|r |cffffffff- Profesiones|r |cff7ce0ffv" .. (RDL_Core.VERSION or "3.6") .. "|r")

gui.subTitle = gui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gui.subTitle:SetPoint("TOPRIGHT", -38, -18)
gui.subTitle:SetTextColor(0.80, 0.95, 1.0)

local closeBtn = CreateFrame("Button", nil, gui, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() CloseTradeSkill(); gui:Hide() end)

-- BARRA DE FILTROS Y DESENCANTAR
local searchBox = CreateFrame("EditBox", "RDL_SearchBox", gui, "InputBoxTemplate")
searchBox:SetSize(165, 22)
searchBox:SetPoint("TOPLEFT", 22, -76)
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function(self) SetTradeSkillItemNameFilter(self:GetText()) end)

gui.onlyMats = CreateFrame("CheckButton", "RDL_OnlyMats", gui, "UICheckButtonTemplate")
gui.onlyMats:SetSize(24, 24)
gui.onlyMats:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
_G["RDL_OnlyMatsText"]:SetText("|cffd4f4ffCon materiales|r")

gui.deOpenBtn = CreateFrame("Button", "RDL_OpenDEBtn", gui, "UIPanelButtonTemplate")
gui.deOpenBtn:SetSize(95, 22)
gui.deOpenBtn:SetPoint("TOPRIGHT", -18, -76)
gui.deOpenBtn:SetText("Desencantar")
gui.deOpenBtn:SetScript("OnClick", function()
    if RDL_Disenchant then RDL_Disenchant.ToggleSelector() end
end)
gui.onlyMats:SetScript("OnClick", function() RDL_MainFrame_Refresh() end)

-- PANEL IZQUIERDO: LISTA DE RECETAS
local listPanel = CreateFrame("Frame", nil, gui)
listPanel:SetSize(250, 365)
listPanel:SetPoint("TOPLEFT", 16, -106)
listPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
listPanel:SetBackdropColor(0.03, 0.13, 0.24, 0.88)
listPanel:SetBackdropBorderColor(0.45, 0.85, 1.0, 0.95)

gui.scrollFrame = CreateFrame("ScrollFrame", "RDL_RecipeScroll", listPanel, "FauxScrollFrameTemplate")
gui.scrollFrame:SetPoint("TOPLEFT", 4, -6)
gui.scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

gui.rowButtons = {}
for i = 1, 17 do
    local row = CreateFrame("Button", nil, listPanel)
    row:SetSize(216, 20)
    row:SetPoint("TOPLEFT", 8, -6 - ((i - 1) * 20))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    gui.rowButtons[i] = row
end

-- PANEL DERECHO: DETALLES DE LA RECETA
local detailPanel = CreateFrame("Frame", nil, gui)
detailPanel:SetSize(270, 365)
detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 8, 0)
detailPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
detailPanel:SetBackdropColor(0.04, 0.16, 0.29, 0.88)
detailPanel:SetBackdropBorderColor(0.45, 0.85, 1.0, 0.95)

gui.itemIcon = CreateFrame("Button", nil, detailPanel)
gui.itemIcon:SetSize(40, 40)
gui.itemIcon:SetPoint("TOPLEFT", 12, -14)
gui.itemIcon.tex = gui.itemIcon:CreateTexture(nil, "ARTWORK")
gui.itemIcon.tex:SetAllPoints()

gui.itemTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gui.itemTitle:SetPoint("LEFT", gui.itemIcon, "RIGHT", 8, 6)
gui.itemTitle:SetPoint("RIGHT", -10, 6)
gui.itemTitle:SetJustifyH("LEFT")
gui.itemTitle:SetTextColor(0.85, 0.96, 1.0)

gui.itemSub = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gui.itemSub:SetPoint("TOPLEFT", gui.itemTitle, "BOTTOMLEFT", 0, -4)

local reqHeader = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
reqHeader:SetPoint("TOPLEFT", 12, -68)
reqHeader:SetText("|cff8ce6ffComponentes:|r")

gui.reagentRows = {}
for i = 1, 8 do
    local rb = CreateFrame("Button", nil, detailPanel)
    rb:SetSize(246, 26)
    rb:SetPoint("TOPLEFT", 12, -88 - ((i - 1) * 28))
    rb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    rb.icon = rb:CreateTexture(nil, "ARTWORK")
    rb.icon:SetSize(22, 22)
    rb.icon:SetPoint("LEFT", 2, 0)
    rb.name = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rb.name:SetPoint("LEFT", rb.icon, "RIGHT", 6, 0)
    rb.name:SetWidth(155)
    rb.name:SetJustifyH("LEFT")
    rb.count = rb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rb.count:SetPoint("RIGHT", -2, 0)
    gui.reagentRows[i] = rb
end

gui.qtyBox = CreateFrame("EditBox", "RDL_QtyBox", detailPanel, "InputBoxTemplate")
gui.qtyBox:SetSize(36, 22)
gui.qtyBox:SetPoint("BOTTOM", detailPanel, "BOTTOM", 10, 14)
gui.qtyBox:SetNumeric(true)
gui.qtyBox:SetAutoFocus(false)
gui.qtyBox:SetText("1")

gui.createBtn = CreateFrame("Button", nil, detailPanel, "UIPanelButtonTemplate")
gui.createBtn:SetSize(84, 24)
gui.createBtn:SetPoint("LEFT", gui.qtyBox, "RIGHT", 6, 0)
gui.createBtn:SetText("Crear")

gui.createAllBtn = CreateFrame("Button", nil, detailPanel, "UIPanelButtonTemplate")
gui.createAllBtn:SetSize(110, 24)
gui.createAllBtn:SetPoint("RIGHT", gui.qtyBox, "LEFT", -6, 0)
gui.createAllBtn:SetText("Crear todos")
