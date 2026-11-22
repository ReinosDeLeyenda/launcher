RDL_ProfList = {}
local profButtons = {}

local PROF_SPELLS = {
    2259,3101,3464,11611,28596,51304,
    2018,3100,3538,9785,29844,51300,
    7411,7412,7413,13920,28029,51313,
    4036,4037,4038,12656,30350,51306,
    45357,45358,45359,45360,45361,45363,
    25229,25230,28894,28895,28897,51311,
    2108,3104,3811,10662,32549,51302,
    3908,3909,3910,12180,26790,51309,
    2656,
    2550,3102,3413,18260,33359,51296,
    3273,3274,7924,10846,27028,45542,
    53428
}

function RDL_ProfList.GetKnown()
    local list, seen = {}, {}
    local spellNames = {}
    for _, id in ipairs(PROF_SPELLS) do
        local n = GetSpellInfo(id)
        if n then spellNames[n] = true end
    end
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name and spellNames[name] and not seen[name] then
                seen[name] = true
                table.insert(list, { name = name, icon = GetSpellTexture(i, BOOKTYPE_SPELL), slot = i })
            end
        end
    end
    return list
end

function RDL_ProfList.RenderTabs(parent)
    local active = GetTradeSkillLine()
    local list = RDL_ProfList.GetKnown()
    for _, b in ipairs(profButtons) do b:Hide() end

    for idx, prof in ipairs(list) do
        local btn = profButtons[idx]
        if not btn then
            btn = CreateFrame("Button", "RDL_TopTab" .. idx, parent)
            btn:SetSize(28, 28)
            btn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 12, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            -- Fondo azul glaciar oscuro y borde hielo apagado
            btn:SetBackdropColor(0.05, 0.14, 0.24, 0.95)
            btn:SetBackdropBorderColor(0.28, 0.58, 0.80, 1)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", -2, 2)
            btn.icon = icon

            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.profName, 0.55, 0.90, 1.0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function(self)
                if self.slot then CastSpell(self.slot, BOOKTYPE_SPELL) end
            end)
            profButtons[idx] = btn
        end

        btn.profName = prof.name
        btn.slot = prof.slot
        btn.icon:SetTexture(prof.icon)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 18 + ((idx - 1) * 32), -38)

        if active and (active == prof.name or active:find(prof.name, 1, true)) then
            -- Borde blanco hielo brillante para la profesion activa
            btn:SetBackdropBorderColor(0.65, 0.95, 1.0, 1)
        else
            btn:SetBackdropBorderColor(0.28, 0.58, 0.80, 1)
        end
        btn:Show()
    end
end
