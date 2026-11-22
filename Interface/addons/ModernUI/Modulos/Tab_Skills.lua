local addonName, NS = ...
local mainUI = NS.mainUI
local CENTER_W = NS.CENTER_WIDTH
local RECIPES_W = 275

local selectedProfFilter = "ALL"
local knownFilterMode = "ALL"
local recipeSearchText = ""

local div1 = mainUI:CreateTexture(nil, "ARTWORK")
div1:SetTexture(0.45, 0.80, 1.0, 0.35)
div1:SetWidth(1)
div1:SetPoint("TOP", mainUI, "TOPLEFT", CENTER_W, -10)
div1:SetPoint("BOTTOM", mainUI, "BOTTOMLEFT", CENTER_W, 10)
div1:Hide()

local container = CreateFrame("Frame", "ModernCharacterRecipesContainer", mainUI)
container:SetPoint("TOPLEFT", mainUI, "TOPLEFT", CENTER_W + 10, -14)
container:SetPoint("BOTTOMLEFT", mainUI, "BOTTOMLEFT", CENTER_W + 10, 10)
container:SetWidth(RECIPES_W - 20)
container:Hide()

local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", container, "TOPLEFT", 2, 0)
title:SetText("|cffb3e5fcCatálogo de Recetas|r")

local profBtn = CreateFrame("Button", nil, container)
profBtn:SetSize(148, 20)
profBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
NS.ApplyIceBackdrop(profBtn, 0.95, 0.08, 0.24, 0.40, 12, 3)

local profText = profBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
profText:SetPoint("LEFT", profBtn, "LEFT", 6, 0)
profText:SetPoint("RIGHT", profBtn, "RIGHT", -6, 0)
profText:SetJustifyH("LEFT")

local stateBtn = CreateFrame("Button", nil, container)
stateBtn:SetHeight(20)
stateBtn:SetPoint("LEFT", profBtn, "RIGHT", 4, 0)
stateBtn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
NS.ApplyIceBackdrop(stateBtn, 0.95, 0.08, 0.24, 0.40, 12, 3)

local stateText = stateBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stateText:SetPoint("CENTER", stateBtn, "CENTER", 0, 0)

local searchBox = CreateFrame("EditBox", "ModernCharacterRecipeSearch", container)
searchBox:SetHeight(20)
searchBox:SetPoint("TOPLEFT", profBtn, "BOTTOMLEFT", 0, -4)
searchBox:SetPoint("TOPRIGHT", stateBtn, "BOTTOMRIGHT", 0, -4)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("GameFontHighlightSmall")
searchBox:SetTextInsets(6, 6, 0, 0)
NS.ApplyIceBackdrop(searchBox, 0.95, 0.03, 0.09, 0.16, 12, 3)
searchBox:SetBackdropBorderColor(0.35, 0.65, 0.85, 0.85)

local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
placeholder:SetText("Buscar receta...")

local scroll = CreateFrame("ScrollFrame", "ModernCharacterRecipesScroll", container, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 18)

local footer = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footer:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 2, 0)
footer:SetTextColor(0.55, 0.88, 1.0)

local VISIBLE_ROWS = 19
local rows, displayList = {}, {}

for i = 1, VISIBLE_ROWS do
    local btn = CreateFrame("Button", nil, container)
    btn:SetHeight(15)
    btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -((i - 1) * 15))
    btn:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -((i - 1) * 15))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(13, 13)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 2, 0)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.text:SetJustifyH("LEFT")

    btn:SetScript("OnEnter", function(self)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if self.recipeName then
            if IsShiftKeyDown() and self.link then
                ChatEdit_InsertLink(self.link)
            else
                if NS.RefreshCraftersForRecipe then NS.RefreshCraftersForRecipe(self.recipeName, self.link) end
                NS.QueryRecipeInGuild(self.recipeName)
            end
        end
    end)
    rows[i] = btn
end

local function RenderScroll()
    local total = #displayList
    FauxScrollFrame_Update(scroll, total, VISIBLE_ROWS, 15)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local entry = displayList[offset + i]
        if entry then
            if entry.isHeader then
                row.icon:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.text:SetText(string.format("|cff7dd3fc%s (%d)|r", entry.name, entry.count))
                row.link, row.recipeName = nil, nil
            else
                row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:Show()
                row.icon:SetDesaturated(not entry.isKnown)
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
                row.text:SetText(entry.isKnown
                    and (entry.link or ("|cffffffff" .. entry.name .. "|r"))
                    or ("|cff94a3b8" .. entry.name .. " [No]|r"))
                row.link, row.recipeName = entry.link, entry.name
            end
            row:Show()
        else
            row:Hide()
            row.link, row.recipeName = nil, nil
        end
    end
end

function NS.RefreshRecipesList()
    if not container:IsVisible() then return end
    wipe(displayList)

    local myKnown = {}
    for profName, recipes in pairs(ModernCharacterUI_RecipesDB or {}) do
        myKnown[profName] = {}
        for _, rec in ipairs(recipes) do myKnown[profName][rec.name] = rec end
    end

    local allProfs, profSet, catalog = NS.GetAvailableProfessions()
    if selectedProfFilter ~= "ALL" and not profSet[selectedProfFilter] then selectedProfFilter = "ALL" end
    profText:SetText(selectedProfFilter == "ALL" and "Prof: Todas" or selectedProfFilter)

    local stateLabels = { ALL = "Todas", KNOWN = "Aprendidas", UNKNOWN = "Faltan" }
    stateText:SetText(stateLabels[knownFilterMode] or "Todas")

    local query = string.lower(recipeSearchText or "")
    local totalCount = 0

    for _, pName in ipairs(allProfs) do
        if selectedProfFilter == "ALL" or selectedProfFilter == pName then
            local merged, seen = {}, {}
            for rName, rec in pairs(myKnown[pName] or {}) do
                if not NS.IsClassRestrictedRecipe or not NS.IsClassRestrictedRecipe(pName, rec.link, rName) then
                    seen[rName] = true
                    table.insert(merged, { name = rName, link = rec.link, icon = rec.icon, isKnown = true })
                end
            end
            for rName, catRec in pairs(catalog[pName] or {}) do
                if not seen[rName] and (not NS.IsClassRestrictedRecipe or not NS.IsClassRestrictedRecipe(pName, catRec.link, rName)) then
                    table.insert(merged, { name = rName, link = catRec.link, icon = catRec.icon, isKnown = false })
                end
            end
            table.sort(merged, function(a, b) return a.name < b.name end)

            local filtered = {}
            for _, rec in ipairs(merged) do
                local passState = (knownFilterMode == "ALL")
                    or (knownFilterMode == "KNOWN" and rec.isKnown)
                    or (knownFilterMode == "UNKNOWN" and not rec.isKnown)
                local passQuery = (query == "") or string.find(string.lower(rec.name), query, 1, true)
                if passState and passQuery then table.insert(filtered, rec) end
            end

            if #filtered > 0 then
                table.insert(displayList, { isHeader = true, name = pName, count = #filtered })
                for _, rec in ipairs(filtered) do
                    table.insert(displayList, rec)
                    totalCount = totalCount + 1
                end
            end
        end
    end

    footer:SetText(#allProfs == 0
        and "Abre una profesión para cargar el catálogo."
        or string.format("Recetas mostradas: |cffffffff%d|r", totalCount))
    RenderScroll()
end

function NS.SetSkillsTabVisible(visible)
    if visible then
        if NS.PopulateStaticRecipeCatalog then NS.PopulateStaticRecipeCatalog() end
        div1:Show(); container:Show()
        NS.RefreshRecipesList()
    else
        div1:Hide(); container:Hide()
    end
    if NS.SetCraftersPanelVisible then NS.SetCraftersPanelVisible(visible) end
end

profBtn:SetScript("OnClick", function()
    local sorted = NS.GetAvailableProfessions()
    local profNames = { "ALL" }
    for _, pName in ipairs(sorted) do table.insert(profNames, pName) end
    for i, name in ipairs(profNames) do
        if name == selectedProfFilter then
            selectedProfFilter = profNames[(i % #profNames) + 1]
            break
        end
    end
    FauxScrollFrame_SetOffset(scroll, 0)
    NS.RefreshRecipesList()
end)

stateBtn:SetScript("OnClick", function()
    knownFilterMode = (knownFilterMode == "ALL" and "KNOWN") or (knownFilterMode == "KNOWN" and "UNKNOWN") or "ALL"
    FauxScrollFrame_SetOffset(scroll, 0)
    NS.RefreshRecipesList()
end)

searchBox:SetScript("OnTextChanged", function(self)
    recipeSearchText = self:GetText()
    if recipeSearchText == "" then placeholder:Show() else placeholder:Hide() end
    FauxScrollFrame_SetOffset(scroll, 0)
    NS.RefreshRecipesList()
end)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 15, RenderScroll)
end)
