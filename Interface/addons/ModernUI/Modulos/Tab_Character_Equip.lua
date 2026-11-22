local addonName, NS = ...
local mainUI = NS.mainUI
local LEFT_W = NS.LEFT_PANEL_WIDTH

local SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

local NO_ENCHANT_SLOTS = {
    NeckSlot = true, WaistSlot = true, Finger0Slot = true, Finger1Slot = true,
    Trinket0Slot = true, Trinket1Slot = true, SecondaryHandSlot = true, RangedSlot = true,
}

local PVP_TYPES = {
    m = "Accesorios PvP", l = "PvP Nivel Bajo", w = "PvP Mundo", g = "Conquista del Invierno",
    s1 = "Temporada 1", s2 = "Temporada 2", s3 = "Temporada 3", s4 = "Temporada 4",
    s5 = "Temporada 5", s6 = "Temporada 6", s7 = "Temporada 7", s8 = "Temporada 8",
}

local SIMPLE_CATS = {
    j = "Emblemas", h = "Emblemas", v = "Emblemas", u = "Emblemas", i = "Emblemas", o = "Emblemas",
    t = "Torneo Argenta", c = "Profesión", f = "Reputación", e = "Evento del Mundo",
    m = "Feria de la Luna Negra", g = "Vendedor"
}

local EQUIP_MOD = {
    INVTYPE_HEAD = 1.0, INVTYPE_NECK = 0.5625, INVTYPE_SHOULDER = 0.75, INVTYPE_CHEST = 1.0,
    INVTYPE_ROBE = 1.0, INVTYPE_WAIST = 0.75, INVTYPE_LEGS = 1.0, INVTYPE_FEET = 0.75,
    INVTYPE_WRIST = 0.5625, INVTYPE_HAND = 0.75, INVTYPE_FINGER = 0.5625, INVTYPE_TRINKET = 0.5625,
    INVTYPE_CLOAK = 0.5625, INVTYPE_WEAPON = 1.0, INVTYPE_SHIELD = 1.0, INVTYPE_2HWEAPON = 2.0,
    INVTYPE_WEAPONMAINHAND = 1.0, INVTYPE_WEAPONOFFHAND = 1.0, INVTYPE_HOLDABLE = 1.0,
    INVTYPE_RANGED = 0.3164, INVTYPE_THROWN = 0.3164, INVTYPE_RANGEDRIGHT = 0.3164, INVTYPE_RELIC = 0.3164
}

local divider = mainUI:CreateTexture(nil, "ARTWORK")
divider:SetTexture(0.45, 0.80, 1.0, 0.35)
divider:SetWidth(1)
divider:SetPoint("TOP", mainUI, "TOPLEFT", LEFT_W, -10)
divider:SetPoint("BOTTOM", mainUI, "BOTTOMLEFT", LEFT_W, 10)

local listTitle = mainUI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
listTitle:SetPoint("TOPLEFT", mainUI, "TOPLEFT", 14, -14)
listTitle:SetText("|cffb3e5fcEquipo y Procedencia|r")

local avgText = mainUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
avgText:SetPoint("BOTTOMLEFT", mainUI, "BOTTOMLEFT", 14, 12)
avgText:SetTextColor(0.55, 0.88, 1.0)

local verBadge = CreateFrame("Button", nil, mainUI)
verBadge:SetSize(82, 16)
verBadge:SetPoint("BOTTOMRIGHT", mainUI, "BOTTOMLEFT", LEFT_W - 10, 10)
verBadge:Hide()

local verBadgeText = verBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
verBadgeText:SetPoint("RIGHT", verBadge, "RIGHT", 0, 0)
verBadgeText:SetText("|cffff5555[Nueva v" .. (NS.latestVersion or "") .. "]|r")

verBadge:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("|cff66ccffActualización de ModernUI|r")
    GameTooltip:AddLine(string.format("Tu versión: |cffff5555v%s|r", NS.VERSION or "?"), 1, 1, 1)
    GameTooltip:AddLine(string.format("Última detectada: |cff4ade80v%s|r", NS.latestVersion or "?"), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Pide la nueva versión a un compañero.", 0.75, 0.90, 1.0)
    GameTooltip:Show()
end)
verBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)

function NS.UpdateVersionBadgeUI()
    if NS.versionOutdated then
        verBadgeText:SetText("|cffff5555[Nueva v" .. (NS.latestVersion or "") .. "]|r")
        if avgText:IsShown() then verBadge:Show() end
    else
        verBadge:Hide()
    end
end

local lines = {}
local MAX_LINES = 24

for i = 1, MAX_LINES do
    local row = CreateFrame("Button", nil, mainUI)
    row:SetSize(LEFT_W - 24, 14)
    row:SetPoint("TOPLEFT", mainUI, "TOPLEFT", 14, -38 - ((i - 1) * 14.5))

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            if self.noEnchant then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffff4444Objeto sin encantar|r")
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.link then
            if IsControlKeyDown() then DressUpItemLink(self.link)
            elseif IsShiftKeyDown() then ChatEdit_InsertLink(self.link) end
        end
    end)
    lines[i] = row
end

local function FindItemCategory(itemLink)
    local IS = InspectEquip_ItemSources
    local id = tonumber(itemLink:match("item:(%d+)"))
    if not id or not IS or not IS.Items then return "Desconocido", nil end

    local data = IS.Items[id]
    if not data then
        local _, _, rarity = GetItemInfo(id)
        return (rarity and rarity >= 2) and "Desconocido / Misión" or nil, nil
    end

    local firstEntry = strsplit(";", data)
    local nextField = gmatch(firstEntry, "[^_]+")
    local cat = nextField()

    if cat == "r" or cat == "d" then
        local zone = (IS.Zones and IS.Zones[tonumber(nextField() or 0)]) or "Instancia"
        local lt = nextField()
        if cat == "r" then
            if lt == "n" or lt == "N" or lt == "q" then zone = zone .. " (10)"
            elseif lt == "h" or lt == "H" or lt == "Q" then zone = zone .. " (25)" end
            if lt == "N" or lt == "H" then zone = zone .. " [H]" end
            return "Banda", zone
        end
        return "Mazmorra", (lt == "h") and (zone .. " [H]") or zone
    elseif cat == "p" then
        return "JcJ", PVP_TYPES[nextField()] or "PvP"
    end
    return SIMPLE_CATS[cat] or "Otro", nil
end

function NS.RefreshEquipmentList()
    for i = 1, MAX_LINES do
        lines[i]:Hide(); lines[i].link = nil; lines[i].noEnchant = false
    end

    local categories, sortedCats = {}, {}
    local ilvlSum, ilvlCount, gsTotal = 0, 0, 0
    local _, playerClass = UnitClass("player")

    for _, slotName in ipairs(SLOTS) do
        local itemLink = GetInventoryItemLink("player", GetInventorySlotInfo(slotName))
        if itemLink then
            local _, _, rarity, iLvl, _, _, _, _, loc = GetItemInfo(itemLink)
            if iLvl then
                ilvlSum = ilvlSum + iLvl
                ilvlCount = ilvlCount + 1

                local mod = loc and EQUIP_MOD[loc]
                if rarity and mod then
                    if playerClass == "HUNTER" then
                        if loc:find("WEAPON") then mod = mod * 0.3164
                        elseif loc:find("RANGED") then mod = 1.0 end
                    end
                    local q = (rarity == 5 and 1.3) or (rarity == 4 and 1.0) or (rarity == 3 and 0.85) or 0.7
                    local b = (iLvl > 120) and ((iLvl - 91.45) / 0.65) or ((iLvl - 81.375) / 0.8125)
                    if b > 0 then gsTotal = gsTotal + math.floor(b * mod * q * 1.8618) end
                end
            end

            local mainCat, subCat = FindItemCategory(itemLink)
            if mainCat then
                local fullCat = subCat and (mainCat .. ": " .. subCat) or mainCat
                categories[fullCat] = categories[fullCat] or {}
                local ench = tonumber(itemLink:match("Hitem:%d+:(%d+):")) or 0
                table.insert(categories[fullCat], {
                    link = itemLink, ilvl = iLvl or 0,
                    noEnchant = (ench == 0) and (not NO_ENCHANT_SLOTS[slotName])
                })
            end
        end
    end

    for catName, items in pairs(categories) do table.insert(sortedCats, { name = catName, items = items }) end
    table.sort(sortedCats, function(a, b) return #a.items > #b.items end)

    local lineIdx = 1
    for _, catData in ipairs(sortedCats) do
        if lineIdx > MAX_LINES then break end
        lines[lineIdx].text:SetText(string.format("|cff7dd3fc%s (%d)|r", catData.name, #catData.items))
        lines[lineIdx]:Show()
        lineIdx = lineIdx + 1

        for _, item in ipairs(catData.items) do
            if lineIdx > MAX_LINES then break end
            local warn = item.noEnchant and " |cffff4444*|r" or ""
            lines[lineIdx].text:SetText(string.format("  |cff80cbc4[%d]|r %s%s", item.ilvl, item.link, warn))
            lines[lineIdx].link = item.link
            lines[lineIdx].noEnchant = item.noEnchant
            lines[lineIdx]:Show()
            lineIdx = lineIdx + 1
        end
    end

    avgText:SetText(ilvlCount > 0
        and string.format("iLvl: |cffffffff%.1f|r  |cff4fc3f7|||r  GS: |cff7dd3fc%d|r", ilvlSum / ilvlCount, gsTotal)
        or "")
    if NS.UpdateVersionBadgeUI then NS.UpdateVersionBadgeUI() end
end

function NS.SetEquipmentPanelVisible(visible)
    for _, w in ipairs({ divider, listTitle, avgText }) do
        if visible then w:Show() else w:Hide() end
    end
    if visible then
        NS.RefreshEquipmentList()
    else
        verBadge:Hide()
        for i = 1, MAX_LINES do lines[i]:Hide() end
    end
end
