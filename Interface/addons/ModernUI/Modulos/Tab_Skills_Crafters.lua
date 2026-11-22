local addonName, NS = ...
local mainUI = NS.mainUI
local CRAFTERS_X = NS.CENTER_WIDTH + 275

local craftersDiv = mainUI:CreateTexture(nil, "ARTWORK")
craftersDiv:SetTexture(0.45, 0.80, 1.0, 0.35)
craftersDiv:SetWidth(1)
craftersDiv:SetPoint("TOP", mainUI, "TOPLEFT", CRAFTERS_X, -10)
craftersDiv:SetPoint("BOTTOM", mainUI, "BOTTOMLEFT", CRAFTERS_X, 10)
craftersDiv:Hide()

local container = CreateFrame("Frame", "ModernCharacterCraftersContainer", mainUI)
container:SetPoint("TOPLEFT", mainUI, "TOPLEFT", CRAFTERS_X + 10, -14)
container:SetPoint("BOTTOMRIGHT", mainUI, "BOTTOMRIGHT", -10, 10)
container:Hide()

local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", container, "TOPLEFT", 2, 0)
title:SetText("|cffb3e5fcConocida por|r")

local recipeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recipeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
recipeLabel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -2, -6)
recipeLabel:SetJustifyH("LEFT")
recipeLabel:SetText("|cff80cbc4Selecciona una receta|r")

local scroll = CreateFrame("ScrollFrame", "ModernCharacterCraftersScroll", container, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", recipeLabel, "BOTTOMLEFT", 0, -8)
scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 18)

local syncBtn = CreateFrame("Button", nil, container)
syncBtn:SetHeight(18)
syncBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
syncBtn:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
NS.ApplyIceBackdrop(syncBtn, 0.95, 0.08, 0.24, 0.40, 12, 3)

local syncText = syncBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
syncText:SetPoint("CENTER", syncBtn, "CENTER", 0, 0)
syncText:SetText("Consultar Hermandad")

local VISIBLE_ROWS = 19
local rows, crafterList = {}, {}
local selectedRecipeName = nil

for i = 1, VISIBLE_ROWS do
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(15)
    row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -((i - 1) * 15))
    row:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -((i - 1) * 15))

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    rows[i] = row
end

local function RenderScroll()
    local total = #crafterList
    FauxScrollFrame_Update(scroll, total, VISIBLE_ROWS, 15)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local entry = crafterList[offset + i]
        if entry then
            local c = RAID_CLASS_COLORS[entry.class] or { r = 1, g = 1, b = 1 }
            local hex = string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            local tag = entry.isOnline and "|cff4ade80(On)|r" or "|cff94a3b8(Off)|r"
            row.text:SetText(string.format("|cff%s%s|r %s", hex, entry.name, tag))
            row:Show()
        else
            row:Hide()
        end
    end
end

function NS.RefreshCraftersForRecipe(recipeName, recipeLink)
    selectedRecipeName = recipeName
    wipe(crafterList)

    if not recipeName then
        recipeLabel:SetText("|cff80cbc4Haz clic en una receta|r")
        RenderScroll()
        return
    end

    recipeLabel:SetText(recipeLink or ("|cffffffff" .. recipeName .. "|r"))

    local onlineGuild = { [UnitName("player")] = true }
    if IsInGuild() then
        for i = 1, GetNumGuildMembers(true) do
            local gName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if gName then onlineGuild[gName] = online end
        end
    end

    local realmDB = ModernCharacterUI_GlobalDB[GetRealmName()] or {}
    for charName, charData in pairs(realmDB) do
        if charName ~= "_Catalog" then
            for _, profRecipes in pairs(charData.profs or {}) do
                if profRecipes[recipeName] then
                    table.insert(crafterList, {
                        name = charName,
                        class = charData.class or "PRIEST",
                        isOnline = onlineGuild[charName] and true or false
                    })
                    break
                end
            end
        end
    end

    table.sort(crafterList, function(a, b)
        if a.isOnline ~= b.isOnline then return a.isOnline end
        return a.name < b.name
    end)

    if #crafterList == 0 then
        table.insert(crafterList, { name = "Nadie registrado aún", class = "PRIEST", isOnline = false })
    end
    RenderScroll()
end

function NS.OnCrafterUpdated(recipeName)
    if container:IsVisible() and selectedRecipeName == recipeName then
        NS.RefreshCraftersForRecipe(selectedRecipeName, recipeLabel:GetText())
    end
end

function NS.SetCraftersPanelVisible(visible)
    if visible then
        craftersDiv:Show(); container:Show()
        NS.RefreshCraftersForRecipe(selectedRecipeName, recipeLabel:GetText())
    else
        craftersDiv:Hide(); container:Hide()
    end
end

syncBtn:SetScript("OnClick", function()
    if IsInGuild() then
        GuildRoster()
        if selectedRecipeName then NS.QueryRecipeInGuild(selectedRecipeName, true) end
    end
end)

scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 15, RenderScroll)
end)
