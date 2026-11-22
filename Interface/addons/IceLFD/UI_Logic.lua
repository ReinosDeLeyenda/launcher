local addonName, addon = ...

local PURE_DPS_CLASSES = {
    MAGE = true,
    ROGUE = true,
    WARLOCK = true,
    HUNTER = true,
}

addon.RACE_ICON_COORDS = {
    ["Human,2"]    = { 0.00, 0.125, 0.00, 0.25 },
    ["Human,3"]    = { 0.00, 0.125, 0.50, 0.75 },
    ["Dwarf,2"]    = { 0.125, 0.25, 0.00, 0.25 },
    ["Dwarf,3"]    = { 0.125, 0.25, 0.50, 0.75 },
    ["Gnome,2"]    = { 0.25, 0.375, 0.00, 0.25 },
    ["Gnome,3"]    = { 0.25, 0.375, 0.50, 0.75 },
    ["NightElf,2"] = { 0.375, 0.50, 0.00, 0.25 },
    ["NightElf,3"] = { 0.375, 0.50, 0.50, 0.75 },
    ["Draenei,2"]  = { 0.50, 0.625, 0.00, 0.25 },
    ["Draenei,3"]  = { 0.50, 0.625, 0.50, 0.75 },
    ["Orc,2"]      = { 0.00, 0.125, 0.25, 0.50 },
    ["Orc,3"]      = { 0.00, 0.125, 0.75, 1.00 },
    ["Scourge,2"]  = { 0.125, 0.25, 0.25, 0.50 },
    ["Scourge,3"]  = { 0.125, 0.25, 0.75, 1.00 },
    ["Tauren,2"]   = { 0.25, 0.375, 0.25, 0.50 },
    ["Tauren,3"]   = { 0.25, 0.375, 0.75, 1.00 },
    ["Troll,2"]    = { 0.375, 0.50, 0.25, 0.50 },
    ["Troll,3"]    = { 0.375, 0.50, 0.75, 1.00 },
    ["BloodElf,2"] = { 0.50, 0.625, 0.25, 0.50 },
    ["BloodElf,3"] = { 0.50, 0.625, 0.75, 1.00 },
}

addon.ROLE_COORDS_LIST = {
    { 0,        67/256,   67/256,  134/256 },
    { 67/256,   134/256,  0,       67/256  },
    { 67/256,   134/256,  67/256,  134/256 },
}

function addon.GetUnitEffectiveRoles(unit, guid)
    local isTank, isHealer, isDPS = UnitGroupRolesAssigned(unit)

    if unit == "player" and not isTank and not isHealer and not isDPS and addon.GetLocalRolesStr then
        local localStr = addon.GetLocalRolesStr()
        isTank = string.find(localStr, "T") ~= nil
        isHealer = string.find(localStr, "H") ~= nil
        isDPS = string.find(localStr, "D") ~= nil
    end

    if isTank or isHealer or isDPS then
        if guid and addon.roleCache then
            local r = ""
            if isTank then r = r .. "T" end
            if isHealer then r = r .. "H" end
            if isDPS then r = r .. "D" end
            addon.roleCache[guid] = r
        end
    elseif guid and addon.roleCache and addon.roleCache[guid] and addon.roleCache[guid] ~= "" then
        local rStr = addon.roleCache[guid]
        isTank = string.find(rStr, "T") ~= nil
        isHealer = string.find(rStr, "H") ~= nil
        isDPS = string.find(rStr, "D") ~= nil
    end

    return isTank, isHealer, isDPS
end

function addon.GetUnitRoleConflicts()
    local units = { "player", "party1", "party2", "party3", "party4" }
    local activeMembers = {}
    local onlyTankUnits, onlyHealerUnits, onlyDPSUnits = {}, {}, {}

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            local t, h, d = addon.GetUnitEffectiveRoles(unit, guid)
            local _, class = UnitClass(unit)
            table.insert(activeMembers, {
                unit = unit,
                t = t,
                h = h,
                d = d,
                isPureDPS = (class and PURE_DPS_CLASSES[class]) or false
            })

            if t and not h and not d then
                table.insert(onlyTankUnits, unit)
            elseif h and not t and not d then
                table.insert(onlyHealerUnits, unit)
            elseif d and not t and not h then
                table.insert(onlyDPSUnits, unit)
            end
        end
    end

    local conflicts = {}

    -- 1. Demasiados jugadores marcados SOLO en un mismo rol fijo
    if #onlyTankUnits >= 2 then
        local msg = string.format("Conflicto de rol: Hay %d jugadores marcados SOLO como Tanque (máximo 1 por mazmorra).", #onlyTankUnits)
        for _, u in ipairs(onlyTankUnits) do
            conflicts[u] = msg
        end
    end

    if #onlyHealerUnits >= 2 then
        local msg = string.format("Conflicto de rol: Hay %d jugadores marcados SOLO como Sanador (máximo 1 por mazmorra).", #onlyHealerUnits)
        for _, u in ipairs(onlyHealerUnits) do
            conflicts[u] = msg
        end
    end

    if #onlyDPSUnits >= 4 then
        local msg = string.format("Conflicto de rol: Hay %d jugadores marcados SOLO como DPS (máximo 3 por mazmorra).", #onlyDPSUnits)
        for _, u in ipairs(onlyDPSUnits) do
            local _, class = UnitClass(u)
            if not (class and PURE_DPS_CLASSES[class]) then
                conflicts[u] = msg
            end
        end
    end

    -- 2. Comprobación matemática de grupo completo (5 jugadores):
    -- Verifica si existe al menos 1 asignación válida (1 Tanque + 1 Sanador + 3 DPS)
    if #activeMembers == 5 and not next(conflicts) then
        local function CanAssign(idx, needT, needH, needD)
            if idx > 5 then
                return (needT == 0 and needH == 0 and needD == 0)
            end
            local m = activeMembers[idx]
            -- Si un jugador no ha marcado ningún rol aún, no bloquea el cálculo
            if not m.t and not m.h and not m.d then
                return true
            end
            if m.t and needT > 0 and CanAssign(idx + 1, needT - 1, needH, needD) then
                return true
            end
            if m.h and needH > 0 and CanAssign(idx + 1, needT, needH - 1, needD) then
                return true
            end
            if m.d and needD > 0 and CanAssign(idx + 1, needT, needH, needD - 1) then
                return true
            end
            return false
        end

        if not CanAssign(1, 1, 1, 3) then
            local msg = "Grupo inviable: Con los roles marcados no se puede formar 1 Tanque, 1 Sanador y 3 DPS (ej. falta quien cubra Tanque o Sanador)."
            for _, m in ipairs(activeMembers) do
                if not m.isPureDPS then
                    conflicts[m.unit] = msg
                end
            end
        end
    end

    return conflicts
end

local function GetRealRandomDungeonMin(dungeonID)
    if dungeonID == 258 then return 15 end
    if dungeonID == 259 then return 58 end
    if dungeonID == 260 then return 70 end
    if dungeonID == 261 then return 68 end
    if dungeonID == 262 then return 80 end
    return nil
end

function addon.GetUnitDungeonIssue(unitIndex, unitLevel)
    local selectedID = (LFDQueueFrame and type(LFDQueueFrame.type) == "number" and LFDQueueFrame.type > 0) and LFDQueueFrame.type or nil

    if selectedID then
        local name, _, _, minLevel = GetLFGDungeonInfo(selectedID)
        local realMin = GetRealRandomDungeonMin(selectedID) or minLevel or 1
        if unitLevel < realMin then
            return true, string.format("Nivel actual: |cffffffff%d|r (mínimo para %s: |cffffffff%d|r).", unitLevel, name or "esta mazmorra", realMin)
        end

        if GetLFDLockInfo then
            local _, _, _, lockReason = GetLFDLockInfo(selectedID, unitIndex)
            if lockReason and lockReason ~= 0 then
                local code = LFG_INSTANCE_INVALID_CODES and LFG_INSTANCE_INVALID_CODES[lockReason] or ""
                local reasonText = _G["INSTANCE_UNAVAILABLE_SELF_" .. code]
                if not reasonText or reasonText == "" then
                    reasonText = "No cumple los requisitos de nivel o equipo para entrar en esta cola."
                end
                return true, string.format("Nivel: |cffffffff%d|r - %s", unitLevel, reasonText)
            end
        end
        return false, nil
    end

    if LFGDungeonList and LFGEnabledList then
        local highestMin = 0
        local dungeonName = nil
        for _, dungeonID in ipairs(LFGDungeonList) do
            if dungeonID > 0 and LFGEnabledList[dungeonID] then
                local name, _, _, minLevel = GetLFGDungeonInfo(dungeonID)
                if minLevel and minLevel > highestMin then
                    highestMin = minLevel
                    dungeonName = name
                end
            end
        end
        if highestMin > 0 then
            if unitLevel < highestMin then
                return true, string.format("Nivel actual: |cffffffff%d|r (mínimo para %s: |cffffffff%d|r).", unitLevel, dungeonName or "las mazmorras marcadas", highestMin)
            end
            return false, nil
        end
    end

    local maxPartyLvl = UnitLevel("player") or 1
    for p = 1, 4 do
        local u = "party" .. p
        if UnitExists(u) then
            local lvl = UnitLevel(u) or 1
            if lvl > maxPartyLvl then maxPartyLvl = lvl end
        end
    end

    local fallbackMin = (maxPartyLvl >= 80) and 68 or (maxPartyLvl - 4)
    if unitLevel < fallbackMin then
        return true, string.format("Nivel actual: |cffffffff%d|r (mínimo recomendado: |cffffffff%d|r).", unitLevel, fallbackMin)
    end

    return false, nil
end

function addon.UpdateIlvlBadge(badge, ilvl)
    if not ilvl or ilvl <= 0 then
        badge.currentIlvl = nil
        badge.text:SetText("?")
        badge.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        return
    end

    badge.currentIlvl = ilvl
    if ilvl < 180 then
        badge.text:SetText(":(")
        badge.bg:SetTexture(0.85, 0.12, 0.12, 0.92)
    elseif ilvl <= 199 then
        badge.text:SetText(":)")
        badge.bg:SetTexture(0.90, 0.75, 0.10, 0.92)
    elseif ilvl <= 209 then
        badge.text:SetText(":))")
        badge.bg:SetTexture(0.15, 0.75, 0.20, 0.92)
    elseif ilvl <= 219 then
        badge.text:SetText(":)))")
        badge.bg:SetTexture(0.15, 0.75, 0.20, 0.92)
    else
        badge.text:SetText("+++")
        badge.bg:SetTexture(0.10, 0.65, 0.95, 0.92)
    end
end

function addon.UpdateDungeonPctBadge(badge, pct, mask)
    if not pct or pct < 0 then
        badge.currentPct = nil
        badge.currentMask = nil
        badge.text:SetText("--")
        badge.bg:SetTexture(0.15, 0.18, 0.24, 0.85)
        return
    end

    badge.currentPct = pct
    badge.currentMask = mask
    badge.text:SetText(pct .. "%")
    if pct < 33 then
        badge.bg:SetTexture(0.85, 0.12, 0.12, 0.92)
    elseif pct < 66 then
        badge.bg:SetTexture(0.90, 0.75, 0.10, 0.92)
    else
        badge.bg:SetTexture(0.15, 0.75, 0.20, 0.92)
    end
end
