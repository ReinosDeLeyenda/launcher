local addonName, NS = ...
local mainUI = NS.mainUI
local STATS_X = NS.LEFT_PANEL_WIDTH + NS.CENTER_WIDTH

local dividerRight = mainUI:CreateTexture(nil, "ARTWORK")
dividerRight:SetTexture(0.45, 0.80, 1.0, 0.35)
dividerRight:SetWidth(1)
dividerRight:SetPoint("TOP", mainUI, "TOPLEFT", STATS_X, -10)
dividerRight:SetPoint("BOTTOM", mainUI, "BOTTOMLEFT", STATS_X, 10)

local statsContainer = CreateFrame("Frame", nil, mainUI)
statsContainer:SetPoint("TOPLEFT", mainUI, "TOPLEFT", STATS_X + 10, -24)
statsContainer:SetPoint("BOTTOMRIGHT", mainUI, "BOTTOMRIGHT", -10, 8)

local STAT_ROWS_CONFIG = {
    { type = "header", text = "Atributos Base" },
    { id = "STR", label = "Fuerza:" }, { id = "AGI", label = "Agilidad:" },
    { id = "STA", label = "Aguante:" }, { id = "INT", label = "Intelecto:" },
    { id = "SPI", label = "Espíritu:" },
    { type = "header", text = "Cuerpo a cuerpo" },
    { id = "M_DMG", label = "Daño:" }, { id = "M_SPD", label = "Velocidad:" },
    { id = "M_AP",  label = "Poder:" }, { id = "M_HIT", label = "Índice de golpe:" },
    { id = "M_CRT", label = "Prob. crítico:" }, { id = "M_EXP", label = "Pericia:" },
    { id = "M_ARP", label = "Pen. armadura:" },
    { type = "header", text = "A distancia" },
    { id = "R_DMG", label = "Daño:" }, { id = "R_SPD", label = "Velocidad:" },
    { id = "R_AP",  label = "Poder:" }, { id = "R_HIT", label = "Índice de golpe:" },
    { id = "R_CRT", label = "Prob. crítico:" }, { id = "R_ARP", label = "Pen. armadura:" },
    { type = "header", text = "Hechizos" },
    { id = "S_DMG", label = "Bonus de daño:" }, { id = "S_HEL", label = "Bonus de sanación:" },
    { id = "S_HIT", label = "Índice de golpe:" }, { id = "S_CRT", label = "Prob. crítico:" },
    { id = "S_HST", label = "Índice de celeridad:" }, { id = "S_REG", label = "Regen. de maná:" },
    { type = "header", text = "Defensas" },
    { id = "D_ARM", label = "Armadura:" }, { id = "D_DEF", label = "Defensa:" },
    { id = "D_DOD", label = "Esquivar:" }, { id = "D_PAR", label = "Parar:" },
    { id = "D_BLK", label = "Bloquear:" }, { id = "D_RES", label = "Temple:" },
}

local statRows = {}
local statRowHeight = 10.2

for i, cfg in ipairs(STAT_ROWS_CONFIG) do
    local f = CreateFrame("Frame", nil, statsContainer)
    f:SetHeight(statRowHeight)
    f:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", 0, -((i - 1) * statRowHeight))
    f:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", 0, -((i - 1) * statRowHeight))

    if cfg.type == "header" then
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h:SetPoint("CENTER", f, "CENTER", 0, 0)
        h:SetText("|cffffffff" .. cfg.text .. "|r")
    else
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", f, "LEFT", 2, 0)
        lbl:SetText(cfg.label)
        lbl:SetTextColor(1, 0.82, 0)

        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("RIGHT", f, "RIGHT", -2, 0)
        val:SetJustifyH("RIGHT")
        statRows[cfg.id] = val
    end
end

local function FormatBaseStat(statIndex)
    local _, stat, posBuff, negBuff = UnitStat("player", statIndex)
    local color = (negBuff < 0 and "ffff2020") or (posBuff > 0 and "ff20ff20") or "ffffffff"
    return string.format("|c%s%d|r", color, stat)
end

function NS.RefreshAllStats()
    if not statsContainer:IsVisible() then return end
    for idx, key in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do
        statRows[key]:SetText(FormatBaseStat(idx))
    end

    local arpText = string.format("%d (%.2f%%)", GetCombatRating(25), GetArmorPenetration())

    local minDmg, maxDmg = UnitDamage("player")
    statRows.M_DMG:SetText(string.format("%d - %d", math.floor(minDmg + 0.5), math.floor(maxDmg + 0.5)))
    statRows.M_SPD:SetText(string.format("%.2f", UnitAttackSpeed("player") or 0))
    local mBase, mPos, mNeg = UnitAttackPower("player")
    statRows.M_AP:SetText(tostring(mBase + mPos + mNeg))
    statRows.M_HIT:SetText(tostring(GetCombatRating(6)))
    statRows.M_CRT:SetText(string.format("%.2f%%", GetCritChance()))
    statRows.M_EXP:SetText(tostring(GetExpertise()))
    statRows.M_ARP:SetText(arpText)

    local rSpeed, rMin, rMax = UnitRangedDamage("player")
    if rSpeed and rSpeed > 0 then
        statRows.R_DMG:SetText(string.format("%d - %d", math.floor(rMin + 0.5), math.floor(rMax + 0.5)))
        statRows.R_SPD:SetText(string.format("%.2f", rSpeed))
    else
        statRows.R_DMG:SetText("N/A"); statRows.R_SPD:SetText("N/A")
    end
    local rBase, rPos, rNeg = UnitRangedAttackPower("player")
    statRows.R_AP:SetText(tostring(rBase + rPos + rNeg))
    statRows.R_HIT:SetText(tostring(GetCombatRating(7)))
    statRows.R_CRT:SetText(string.format("%.2f%%", GetRangedCritChance()))
    statRows.R_ARP:SetText(arpText)

    local maxSpellDmg, maxSpellCrit = 0, 0
    for school = 2, 7 do
        maxSpellDmg = math.max(maxSpellDmg, GetSpellBonusDamage(school))
        maxSpellCrit = math.max(maxSpellCrit, GetSpellCritChance(school))
    end
    statRows.S_DMG:SetText(tostring(maxSpellDmg))
    statRows.S_HEL:SetText(tostring(GetSpellBonusHealing()))
    statRows.S_HIT:SetText(tostring(GetCombatRating(8)))
    statRows.S_CRT:SetText(string.format("%.2f%%", maxSpellCrit))
    statRows.S_HST:SetText(tostring(GetCombatRating(20)))
    statRows.S_REG:SetText(tostring(math.floor((GetManaRegen() * 5) + 0.5)))

    local _, effectiveArmor = UnitArmor("player")
    local baseDef, armorDef = UnitDefense("player")
    statRows.D_ARM:SetText(tostring(effectiveArmor))
    statRows.D_DEF:SetText(tostring(baseDef + armorDef))
    statRows.D_DOD:SetText(string.format("%.2f%%", GetDodgeChance()))
    statRows.D_PAR:SetText(string.format("%.2f%%", GetParryChance()))
    statRows.D_BLK:SetText(string.format("%.2f%%", GetBlockChance()))
    statRows.D_RES:SetText(tostring(GetCombatRating(15)))
end

function NS.SetStatsPanelVisible(visible)
    if visible then
        dividerRight:Show(); statsContainer:Show()
        NS.RefreshAllStats()
    else
        dividerRight:Hide(); statsContainer:Hide()
    end
end
