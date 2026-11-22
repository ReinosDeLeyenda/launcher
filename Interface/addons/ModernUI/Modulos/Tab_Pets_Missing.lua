local addonName, NS = ...
local mainUI = NS.mainUI

local missingCompanionsList = {}
local missingRows = {}
local MISSING_VISIBLE_ROWS = 9
local ROW_HEIGHT = 34

local missingDivider = mainUI:CreateTexture(nil, "ARTWORK")
missingDivider:SetTexture(0.45, 0.80, 1.0, 0.35)
missingDivider:SetWidth(1)
missingDivider:SetPoint("TOP", mainUI, "TOPLEFT", 605, -10)
missingDivider:SetPoint("BOTTOM", mainUI, "BOTTOMLEFT", 605, 10)
missingDivider:Hide()

local missingContainer = CreateFrame("Frame", "ModernCharacterMissingPetsContainer", mainUI)
missingContainer:SetPoint("TOPLEFT", mainUI, "TOPLEFT", 613, -14)
missingContainer:SetPoint("BOTTOMRIGHT", mainUI, "BOTTOMRIGHT", -10, 10)
missingContainer:Hide()

local missingTitle = missingContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
missingTitle:SetPoint("TOPLEFT", missingContainer, "TOPLEFT", 2, 0)
missingTitle:SetText("|cffb3e5fcNo Aprendidas|r")

local missingScroll = CreateFrame("ScrollFrame", "ModernCharacterMissingPetsScroll", missingContainer, "FauxScrollFrameTemplate")
missingScroll:SetPoint("TOPLEFT", missingTitle, "BOTTOMLEFT", 0, -8)
missingScroll:SetPoint("BOTTOMRIGHT", missingContainer, "BOTTOMRIGHT", -22, 18)

local missingFooter = missingContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
missingFooter:SetPoint("BOTTOMLEFT", missingContainer, "BOTTOMLEFT", 2, 0)
missingFooter:SetTextColor(0.55, 0.88, 1.0)

for i = 1, MISSING_VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, missingContainer)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", missingScroll, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", missingScroll, "TOPRIGHT", 0, -((i - 1) * ROW_HEIGHT))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sourceText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -1)
    row.sourceText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.sourceText:SetHeight(20)
    row.sourceText:SetJustifyH("LEFT")
    row.sourceText:SetJustifyV("TOP")
    row.sourceText:SetWordWrap(true)

    row:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("spell:" .. self.spellID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.spellID and IsShiftKeyDown() then
            ChatEdit_InsertLink(string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", self.spellID, self.name or ""))
        end
    end)
    missingRows[i] = row
end

local function RenderMissingScroll()
    local total = #missingCompanionsList
    FauxScrollFrame_Update(missingScroll, total, MISSING_VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(missingScroll)

    for i = 1, MISSING_VISIBLE_ROWS do
        local row = missingRows[i]
        local entry = missingCompanionsList[offset + i]
        if entry then
            row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText("|cffffffff" .. entry.name .. "|r")
            row.sourceText:SetText("|cff7dd3fc" .. (entry.source or "Desconocido") .. "|r")
            row.spellID, row.name = entry.spellID, entry.name
            row:Show()
        else
            row:Hide(); row.spellID = nil
        end
    end
end

function NS.RefreshMissingCompanionsList()
    if not missingContainer:IsVisible() then return end
    wipe(missingCompanionsList)

    local mode = (PetPaperDollFrameCompanionFrame and PetPaperDollFrameCompanionFrame.mode) or "CRITTER"
    local ownedSpells = {}
    for i = 1, (GetNumCompanions(mode) or 0) do
        local _, _, spellID = GetCompanionInfo(mode, i)
        if spellID then ownedSpells[spellID] = true end
    end

    local catalog = (NS.GetCompanionCatalog and NS.GetCompanionCatalog(mode)) or {}
    for _, item in ipairs(catalog) do
        if not ownedSpells[item.spellID] then table.insert(missingCompanionsList, item) end
    end

    local label = (mode == "MOUNT") and "Monturas faltantes: " or "Mascotas faltantes: "
    missingFooter:SetText(label .. "|cffffffff" .. #missingCompanionsList .. "|r")
    RenderMissingScroll()
end

function NS.SetPetsExtraPanelVisible(visible)
    local isCombatPet = PetPaperDollFramePetFrame and PetPaperDollFramePetFrame:IsShown()
    local active = visible and (not isCombatPet)
    if active then
        missingDivider:Show(); missingContainer:Show()
        NS.RefreshMissingCompanionsList()
    else
        missingDivider:Hide(); missingContainer:Hide()
    end
end

missingScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RenderMissingScroll)
end)
