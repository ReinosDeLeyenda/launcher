local addonName, NS = ...

local function UpdateSpellBookTextsAndSlots()
    if not SpellBookFrame or not SpellBookFrame:IsShown() then return end

    if SpellBookTitleText then SpellBookTitleText:SetTextColor(0.75, 0.94, 1.0) end
    if SpellBookPageText then SpellBookPageText:SetTextColor(0.85, 0.96, 1.0) end

    for i = 1, SPELLS_PER_PAGE or 12 do
        local btn = _G["SpellButton" .. i]
        if btn then
            local name = btn:GetName()
            local spellName = _G[name .. "SpellName"]
            local subSpellName = _G[name .. "SubSpellName"]
            local bg = _G[name .. "Background"]

            if bg then bg:SetTexture(nil); bg:Hide() end

            if not btn.iceSlotBg then
                local slotBg = btn:CreateTexture(nil, "BACKGROUND")
                slotBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                slotBg:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
                slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 118, -3)
                slotBg:SetVertexColor(0.08, 0.26, 0.48, 0.55)
                btn.iceSlotBg = slotBg
            end

            if spellName and spellName:IsShown() then spellName:SetTextColor(1.0, 1.0, 1.0) end
            if subSpellName and subSpellName:IsShown() then subSpellName:SetTextColor(0.60, 0.88, 1.0) end
        end
    end
end

function NS.InitSpellBookTheme()
    if not SpellBookFrame then return end

    NS.CreateMainWindowBG(SpellBookFrame, "ModernSpellBookMainBG", {
        portraits = { SpellBookFramePortrait },
        closeBtn = SpellBookCloseButton
    })

    NS.TintButtons({ SpellBookPrevPageButton, SpellBookNextPageButton })
    for i = 1, 8 do
        NS.TintFrameRegions(_G["SpellBookSkillLineTab" .. i])
    end

    NS.StyleTabs("SpellBookFrameTabButton", 5, 0.90)

    if SpellBookFrame_Update then
        hooksecurefunc("SpellBookFrame_Update", UpdateSpellBookTextsAndSlots)
    end
    SpellBookFrame:HookScript("OnShow", UpdateSpellBookTextsAndSlots)
    UpdateSpellBookTextsAndSlots()
end
