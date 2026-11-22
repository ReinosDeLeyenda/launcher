local addonName, addon = ...

local function UpdateRoleBoxes(slot, unit, guid)
    local isTank, isHealer, isDPS = addon.GetUnitEffectiveRoles(unit, guid)
    local states = { isTank, isHealer, isDPS }

    for idx = 1, 3 do
        local box = slot.roleBoxes[idx]
        box:Show()
        if states[idx] then
            box.icon:SetDesaturated(false)
            box.icon:SetAlpha(1.0)
        else
            box.icon:SetDesaturated(true)
            box.icon:SetAlpha(0.25)
        end
    end
end

function addon.ApplyPortraitAppearance(slotIndex, slot, unit, guid)
    addon.CaptureUnitMeta(unit, guid)
    addon.pendingDress[slotIndex] = nil

    if UnitIsVisible(unit) then
        slot.raceTex:Hide()
        slot.liveTex:Show()
        SetPortraitTexture(slot.liveTex, unit)
    else
        slot.liveTex:Hide()
        slot.raceTex:Show()

        local meta = guid and addon.metaCache[guid]
        local coords = meta and addon.RACE_ICON_COORDS[meta]
        if coords then
            slot.raceTex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races")
            slot.raceTex:SetTexCoord(unpack(coords))
        else
            local _, class = UnitClass(unit)
            local classCoords = class and CLASS_ICON_TCOORDS[class]
            if classCoords then
                slot.raceTex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
                slot.raceTex:SetTexCoord(unpack(classCoords))
            else
                slot.raceTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                slot.raceTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
    end
end

function addon.UpdatePartyDisplay()
    local numParty = GetNumPartyMembers()
    if numParty == 0 then
        addon.PartySideFrame:Hide()
        return
    end

    addon.PartySideFrame:Show()
    local roleConflicts = addon.GetUnitRoleConflicts()
    local anyPartyIssue = false
    local anyOffline = false

    for i = 1, 4 do
        local slot = addon.MemberSlots[i]
        local unit = "party" .. i

        if UnitExists(unit) then
            slot:Show()
            local guid = UnitGUID(unit)
            local isConnected = UnitIsConnected(unit)

            if not isConnected then
                anyOffline = true
                anyPartyIssue = true
                if slot.offlineWarn then slot.offlineWarn:Show() end
            else
                if slot.offlineWarn then slot.offlineWarn:Hide() end
            end

            addon.ApplyPortraitAppearance(i, slot, unit, guid)
            UpdateRoleBoxes(slot, unit, guid)

            local dPct = guid and addon.dungeonPctCache and addon.dungeonPctCache[guid] or nil
            local dMask = guid and addon.dungeonMaskCache and addon.dungeonMaskCache[guid] or nil
            addon.UpdateDungeonPctBadge(slot.pctBadge, dPct, dMask)

            if roleConflicts[unit] then
                slot.roleWarn.reason = roleConflicts[unit]
                slot.roleWarn:Show()
                anyPartyIssue = true
            else
                slot.roleWarn:Hide()
            end

            local unspent = guid and addon.talentCache and addon.talentCache[guid] or 0
            if unspent > 0 then
                slot.talentWarn.unspentPoints = unspent
                slot.talentWarn:Show()
                anyPartyIssue = true
            else
                slot.talentWarn:Hide()
            end

            local unitLevel = UnitLevel(unit) or 0
            local hasLevelIssue, levelReason = addon.GetUnitDungeonIssue(i + 1, unitLevel)
            if unitLevel > 0 and hasLevelIssue then
                slot.levelWarn.reason = levelReason
                slot.levelWarn:Show()
                anyPartyIssue = true
            else
                slot.levelWarn:Hide()
            end

            local name = UnitName(unit) or "Desconocido"
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
            if not isConnected then
                slot.nameText:SetText(name .. " |cffff3333(Desconectado)|r")
                slot.nameText:SetTextColor(0.55, 0.55, 0.55)
            else
                slot.nameText:SetText(name)
                slot.nameText:SetTextColor(color.r, color.g, color.b)
            end

            local resolvedIlvl = nil
            if guid and addon.ilvlCache[guid] then
                resolvedIlvl = addon.ilvlCache[guid]
                slot.ilvlText:SetText(string.format("|cff73d2ffiLvl:|r %d", resolvedIlvl))
                addon.UpdateIlvlBadge(slot.ilvlBadge, resolvedIlvl)
            elseif not isConnected then
                slot.ilvlText:SetText("|cff888888Desconectado|r")
                addon.UpdateIlvlBadge(slot.ilvlBadge, nil)
            else
                local directIlvl, directGear = addon.ScanUnitData(unit)
                local meta = addon.CaptureUnitMeta(unit, guid)
                if directIlvl > 0 and guid then
                    resolvedIlvl = directIlvl
                    addon.ilvlCache[guid] = directIlvl
                    if directGear then addon.gearCache[guid] = directGear end
                    addon.BroadcastUnitData(guid, directIlvl, directGear, meta)
                    addon.ApplyPortraitAppearance(i, slot, unit, guid)
                    slot.ilvlText:SetText(string.format("|cff73d2ffiLvl:|r %d", directIlvl))
                    addon.UpdateIlvlBadge(slot.ilvlBadge, directIlvl)
                elseif CheckInteractDistance(unit, 1) and CanInspect(unit) then
                    slot.ilvlText:SetText("|cffaaaaaaEscaneando...|r")
                    addon.UpdateIlvlBadge(slot.ilvlBadge, nil)
                    addon.inspectQueue[unit] = true
                else
                    slot.ilvlText:SetText("|cff888888Lejos para iLvl|r")
                    addon.UpdateIlvlBadge(slot.ilvlBadge, nil)
                end
            end

            if resolvedIlvl and resolvedIlvl > 0 and resolvedIlvl < 180 then
                slot.gearWarn.currentIlvl = resolvedIlvl
                if hasLevelIssue or unitLevel < 78 then
                    slot.gearWarn.isRed = true
                    slot.gearWarn.tex:SetVertexColor(1.0, 0.15, 0.15)
                else
                    slot.gearWarn.isRed = false
                    slot.gearWarn.tex:SetVertexColor(1.0, 0.85, 0.1)
                end
                slot.gearWarn:Show()
                anyPartyIssue = true
            else
                slot.gearWarn:Hide()
            end
        else
            slot:Hide()
            addon.pendingDress[i] = nil
        end
    end

    -- Actualizar caja inferior del jugador local ("player")
    local myLevel = UnitLevel("player") or 0
    local myUnspent = addon.GetUnspentTalents("player", false)
    local myIlvl = addon.ScanUnitData("player")
    local myHasLvlIssue, myLvlReason = addon.GetUnitDungeonIssue(1, myLevel)

    if roleConflicts["player"] then
        addon.myRoleWarn.reason = roleConflicts["player"]
        addon.myRoleWarn:Show()
    else
        addon.myRoleWarn:Hide()
    end

    if myUnspent > 0 then
        addon.myTalentWarn.reason = string.format("Tienes |cffffffff%d|r punto(s) de talento sin gastar.", myUnspent)
        addon.myTalentWarn:Show()
    else
        addon.myTalentWarn:Hide()
    end

    if myIlvl and myIlvl > 0 and myIlvl < 180 then
        if myHasLvlIssue or myLevel < 78 then
            addon.myGearWarn.titleText = "|cffff3333Equipo limitado por nivel|r"
            addon.myGearWarn.tex:SetVertexColor(1.0, 0.15, 0.15)
            addon.myGearWarn.reason = string.format("Nivel de equipo actual: |cffffffff%d|r (inferior a 180).\nAl no tener nivel suficiente no puedes equiparte objetos mejores.", myIlvl)
        else
            addon.myGearWarn.titleText = "|cffffd700Equipo de nivel bajo|r"
            addon.myGearWarn.tex:SetVertexColor(1.0, 0.85, 0.1)
            addon.myGearWarn.reason = string.format("Nivel de equipo actual: |cffffffff%d|r (inferior a 180).", myIlvl)
        end
        addon.myGearWarn:Show()
    else
        addon.myGearWarn:Hide()
    end

    if myLevel > 0 and myHasLvlIssue then
        addon.myLevelWarn.reason = myLvlReason
        addon.myLevelWarn:Show()
    else
        addon.myLevelWarn:Hide()
    end

    if addon.versionOutdated then
        addon.myVersionWarn.reason = string.format("Tu versión: |cffff5555v%s|r\nVersión más reciente detectada: |cff4ade80v%s|r\n\nPide la actualización a un compañero de grupo.", addon.VERSION, addon.latestVersion)
        addon.myVersionWarn:Show()
    else
        addon.myVersionWarn:Hide()
    end

    local prevIcon = nil
    for _, icon in ipairs(addon.myWarnIcons) do
        if icon:IsShown() then
            icon:ClearAllPoints()
            if not prevIcon then
                icon:SetPoint("LEFT", addon.playerTitle, "RIGHT", 8, 0)
            else
                icon:SetPoint("LEFT", prevIcon, "RIGHT", 4, 0)
            end
            prevIcon = icon
        end
    end

    if prevIcon then
        addon.playerOkText:Hide()
    else
        addon.playerOkText:Show()
        if anyOffline then
            addon.playerOkText:SetText("|cffff3333Hay jugadores desconectados|r")
        elseif anyPartyIssue then
            addon.playerOkText:SetText("|cffffd700Revisa avisos del grupo|r")
        else
            addon.playerOkText:SetText("|cff4ade80Todo listo|r")
        end
    end
end
