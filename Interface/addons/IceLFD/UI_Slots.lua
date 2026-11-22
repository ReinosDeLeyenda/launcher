local addonName, addon = ...

addon.MemberSlots = {}

for i = 1, 4 do
    local slot = CreateFrame("Frame", "IceLFD_MemberSlot" .. i, addon.PartySideFrame)
    slot:SetSize(330, 82)
    slot:SetPoint("TOPLEFT", addon.PartySideFrame, "TOPLEFT", 10, -32 - ((i - 1) * 86))

    local border = CreateFrame("Frame", nil, slot)
    border:SetSize(48, 48)
    border:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    border:SetBackdropBorderColor(addon.ICE_R, addon.ICE_G, addon.ICE_B, 1)

    local liveTex = border:CreateTexture(nil, "ARTWORK")
    liveTex:SetSize(40, 40)
    liveTex:SetPoint("CENTER", 0, 0)
    slot.liveTex = liveTex

    local raceTex = border:CreateTexture(nil, "ARTWORK")
    raceTex:SetSize(40, 40)
    raceTex:SetPoint("CENTER", 0, 0)
    slot.raceTex = raceTex

    local ilvlBadge = CreateFrame("Frame", nil, slot)
    ilvlBadge:SetSize(34, 24)
    ilvlBadge:SetPoint("TOPLEFT", border, "TOPRIGHT", 3, 0)
    ilvlBadge:EnableMouse(true)
    ilvlBadge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 6 })
    ilvlBadge:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)

    local badgeBg = ilvlBadge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetPoint("TOPLEFT", 1, -1)
    badgeBg:SetPoint("BOTTOMRIGHT", -1, 1)
    ilvlBadge.bg = badgeBg

    local badgeText = ilvlBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badgeText:SetPoint("CENTER", 0, 0)
    badgeText:SetTextColor(1, 1, 1)
    badgeText:SetShadowOffset(1, -1)
    ilvlBadge.text = badgeText

    ilvlBadge:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cff73d2ffNivel de Equipo (iLvl)|r")
        if self.currentIlvl then
            GameTooltip:AddLine(string.format("Actual: |cffffffff%d|r", self.currentIlvl), 1, 1, 1)
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine("|cffff3333Rojo :(|r : Menos de 180", 1, 1, 1)
        GameTooltip:AddLine("|cffffd700Amarillo :)|r : 180 a 199", 1, 1, 1)
        GameTooltip:AddLine("|cff33ff33Verde :))|r : 200 a 209", 1, 1, 1)
        GameTooltip:AddLine("|cff33ff33Verde :)))|r : 210 a 219", 1, 1, 1)
        GameTooltip:AddLine("|cff33ccffAzul +++|r : 220 en adelante", 1, 1, 1)
        GameTooltip:Show()
    end)
    ilvlBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot.ilvlBadge = ilvlBadge

    local pctBadge = CreateFrame("Frame", nil, slot)
    pctBadge:SetSize(34, 24)
    pctBadge:SetPoint("TOP", ilvlBadge, "BOTTOM", 0, 0)
    pctBadge:EnableMouse(true)
    pctBadge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 6 })
    pctBadge:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)

    local pctBg = pctBadge:CreateTexture(nil, "BACKGROUND")
    pctBg:SetPoint("TOPLEFT", 1, -1)
    pctBg:SetPoint("BOTTOMRIGHT", -1, 1)
    pctBadge.bg = pctBg

    local pctText = pctBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctText:SetPoint("CENTER", 0, 0)
    pctText:SetTextColor(1, 1, 1)
    pctText:SetShadowOffset(1, -1)
    pctBadge.text = pctText

    pctBadge:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cff73d2ffMazmorras de Rasganorte Completadas|r")
        if self.currentPct then
            GameTooltip:AddLine(string.format("Progreso: |cffffffff%d%%|r", self.currentPct), 1, 1, 1)

            if self.currentMask and self.currentMask >= 0 and addon.WOTLK_DUNGEON_ACHIEVEMENTS then
                local showMissing = (self.currentPct >= 50)
                local list = {}

                for idx, entry in ipairs(addon.WOTLK_DUNGEON_ACHIEVEMENTS) do
                    local isDone = bit.band(self.currentMask, bit.lshift(1, idx - 1)) ~= 0
                    if (showMissing and not isDone) or (not showMissing and isDone) then
                        local _, achName = GetAchievementInfo(entry[1])
                        local cleanName = achName and string.gsub(achName, "^.-:%s*", "") or entry[3]
                        table.insert(list, cleanName)
                    end
                end

                GameTooltip:AddLine(" ")
                if showMissing then
                    if #list == 0 then
                        GameTooltip:AddLine("|cff4ade80¡Todas las mazmorras completadas!|r", 1, 1, 1)
                    else
                        GameTooltip:AddLine(string.format("|cffffd700Mazmorras que le faltan (%d):|r", #list), 1, 1, 1)
                        for _, dName in ipairs(list) do
                            GameTooltip:AddLine(" - " .. dName, 1, 0.4, 0.4)
                        end
                    end
                else
                    if #list == 0 then
                        GameTooltip:AddLine("|cffff3333Ninguna mazmorra completada aún.|r", 1, 1, 1)
                    else
                        GameTooltip:AddLine(string.format("|cff4ade80Mazmorras completadas (%d):|r", #list), 1, 1, 1)
                        for _, dName in ipairs(list) do
                            GameTooltip:AddLine(" - " .. dName, 0.4, 1, 0.5)
                        end
                    end
                end
            end
        else
            GameTooltip:AddLine("Sin datos (requiere que el jugador tenga IceLFD)", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)

    pctBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot.pctBadge = pctBadge

    slot.roleBoxes = {}
    local lastRoleBox = nil
    for r = 1, 3 do
        local rBox = CreateFrame("Frame", nil, slot)
        rBox:SetSize(48, 48)
        if r == 1 then
            rBox:SetPoint("TOPLEFT", ilvlBadge, "TOPRIGHT", 3, 0)
        else
            rBox:SetPoint("LEFT", lastRoleBox, "RIGHT", 2, 0)
        end
        rBox:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        rBox:SetBackdropBorderColor(addon.ICE_R, addon.ICE_G, addon.ICE_B, 1)

        local rBg = rBox:CreateTexture(nil, "BACKGROUND")
        rBg:SetPoint("TOPLEFT", 3, -3)
        rBg:SetPoint("BOTTOMRIGHT", -3, 3)
        rBg:SetTexture(0.03, 0.08, 0.15, 0.9)

        local rIcon = rBox:CreateTexture(nil, "ARTWORK")
        rIcon:SetSize(40, 40)
        rIcon:SetPoint("CENTER", 0, 0)
        rIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
        rIcon:SetTexCoord(unpack(addon.ROLE_COORDS_LIST[r]))
        rBox.icon = rIcon

        slot.roleBoxes[r] = rBox
        lastRoleBox = rBox
    end
    slot.thirdRoleBox = lastRoleBox

    slot.roleWarn = addon.CreateIceWarnIcon(slot, 1.0, 0.85, 0.1, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd700Rol incompatible en grupo|r")
        GameTooltip:AddLine(self.reason or "Este rol impide completar el grupo de 5 jugadores.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slot.roleWarn:SetPoint("TOPLEFT", slot.thirdRoleBox, "TOPRIGHT", 4, 0)

    slot.talentWarn = addon.CreateIceWarnIcon(slot, 1.0, 0.85, 0.1, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd700Talentos incompletos|r")
        GameTooltip:AddLine(string.format("Tiene |cffffffff%d|r punto(s) de talento sin gastar.", self.unspentPoints or 0), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slot.talentWarn:SetPoint("BOTTOMLEFT", slot.thirdRoleBox, "BOTTOMRIGHT", 4, 0)

    slot.gearWarn = addon.CreateIceWarnIcon(slot, 1.0, 0.85, 0.1, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local lvl = self.currentIlvl or 0
        if self.isRed then
            GameTooltip:SetText("|cffff3333Equipo limitado por nivel|r")
            GameTooltip:AddLine(string.format("Nivel de equipo actual: |cffffffff%d|r (inferior a 180).\nAl no tener el nivel suficiente no puede equiparse equipo de mayor nivel.", lvl), 1, 0.82, 0, true)
        else
            GameTooltip:SetText("|cffffd700Equipo de nivel bajo|r")
            GameTooltip:AddLine(string.format("Nivel de equipo actual: |cffffffff%d|r (inferior a 180).", lvl), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    slot.gearWarn:SetPoint("TOPLEFT", slot.thirdRoleBox, "TOPRIGHT", 28, 0)

    slot.levelWarn = addon.CreateIceWarnIcon(slot, 1.0, 0.15, 0.15, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffff3333Nivel o requisito insuficiente|r")
        GameTooltip:AddLine(self.reason or "El nivel de este personaje es insuficiente.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    slot.levelWarn:SetPoint("BOTTOMLEFT", slot.thirdRoleBox, "BOTTOMRIGHT", 28, 0)

    slot.offlineWarn = addon.CreateIceWarnIcon(slot, 1.0, 0.15, 0.15, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffff3333Jugador desconectado|r")
        GameTooltip:AddLine("Este miembro del grupo está desconectado y no se puede entrar en cola.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    slot.offlineWarn:SetPoint("LEFT", slot.levelWarn, "RIGHT", 4, 0)

    local nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -3)
    nameText:SetWidth(310)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    slot.nameText = nameText

    local ilvlText = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ilvlText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
    slot.ilvlText = ilvlText

    slot:Hide()
    addon.MemberSlots[i] = slot
end
