local ui = RDL_DE_UI
local selectedItem = nil
local targetRemaining, targetTotal = 0, 0
local filteredCache = {}
local lastBag, lastSlot = nil, nil
local waitingBagUpdate = false
local movingFromBank = false

local SORT_OPTIONS = {
    { text = "Cantidad (Mas a menos)", value = "count_desc" },
    { text = "Cantidad (Menos a mas)", value = "count_asc" },
    { text = "Nivel (Mas a menos)",    value = "lvl_desc" },
    { text = "Nivel (Menos a mas)",    value = "lvl_asc" }
}

UIDropDownMenu_Initialize(ui.sortDrop, function(self, level)
    for _, opt in ipairs(SORT_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.checked = (RDL_Disenchant.Filters.sortBy == opt.value)
        info.func = function(btn)
            RDL_Disenchant.Filters.sortBy = btn.value
            UIDropDownMenu_SetText(ui.sortDrop, opt.text)
            RDL_Disenchant.RefreshList()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

for i = 1, 9 do
    local b = ui.rows[i]
    b:SetScript("OnEnter", function(self)
        if self.itemData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemData.link)
            GameTooltip:AddLine("Nivel de objeto: " .. self.itemData.iLvl, 0.8, 0.8, 0.8)
            if self.itemData.bound then GameTooltip:AddLine("Estado: Ligado al alma", 1, 0.3, 0.3) end
            if self.itemData.bankCount and self.itemData.bankCount > 0 then
                GameTooltip:AddLine("En banco personal: " .. self.itemData.bankCount, 0.4, 0.8, 1)
            end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        selectedItem = self.itemData
        ui.qtyBox:SetText(tostring(selectedItem.count))
        RDL_Disenchant.RefreshList()
    end)
end

ui.scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 24, RDL_Disenchant.RefreshList)
end)

StaticPopupDialogs["RDL_DE_CONFIRM_EPIC_1"] = {
    text = "|cffff3333ATENCION:|r Vas a desencantar un objeto |cffa335eeEPICO LIGADO|r (%s).\n\n¿Estas seguro?",
    button1 = "Si, estoy seguro",
    button2 = "Cancelar",
    OnAccept = function(_, data)
        StaticPopup_Show("RDL_DE_CONFIRM_EPIC_2", data.name, nil, data)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true
}

StaticPopupDialogs["RDL_DE_CONFIRM_EPIC_2"] = {
    text = "|cffff0000ULTIMA ADVERTENCIA:|r El objeto |cffa335ee%s|r se destruira permanentemente.\n\n¿Estas REALMENTE seguro?",
    button1 = "SI, DESENCANTAR",
    button2 = "No, cancelar",
    OnAccept = function(_, data)
        RDL_Disenchant.BeginExecution(data.item, data.count)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true
}

ui.startBtn:SetScript("OnClick", function()
    if not selectedItem then return end
    local n = math.max(1, tonumber(ui.qtyBox:GetText()) or 1)
    if selectedItem.quality == 4 and selectedItem.bound then
        StaticPopup_Show("RDL_DE_CONFIRM_EPIC_1", selectedItem.name, nil, { item = selectedItem, count = n, name = selectedItem.name })
    else
        RDL_Disenchant.BeginExecution(selectedItem, n)
    end
end)

ui.cancelBtn:SetScript("OnClick", function()
    targetRemaining = 0
    waitingBagUpdate = false
    movingFromBank = false
    lastBag, lastSlot = nil, nil
    ui.execFrame:Hide()
end)

local function FindFreePlayerBagSlot()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                if not GetContainerItemID(bag, slot) then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

local function SetReadyButton(bag, slot)
    lastBag, lastSlot = bag, slot
    local spellName = GetSpellInfo(RDL_Disenchant.GetSpellID()) or "Desencantar"
    ui.actionBtn:SetAttribute("type", "macro")
    ui.actionBtn:SetAttribute("macrotext", "/stopcasting\n/cast " .. spellName .. "\n/use " .. bag .. " " .. slot)
    ui.execStatus:SetText(selectedItem.name .. " (" .. targetRemaining .. " / " .. targetTotal .. ")")
    ui.actionBtn:SetText("Desencantar (" .. targetRemaining .. ")")
    ui.actionBtn:Enable()
    ui.execFrame:Show()
end

local function PrepareNext(ignoreLastSlot)
    if InCombatLockdown() then return end
    if SpellIsTargeting() then SpellStopTargeting() end
    if targetRemaining <= 0 or not selectedItem then
        waitingBagUpdate = false
        movingFromBank = false
        lastBag, lastSlot = nil, nil
        ui.execFrame:Hide()
        return
    end

    local skipB = ignoreLastSlot and lastBag or nil
    local skipS = ignoreLastSlot and lastSlot or nil
    local bag, slot = RDL_Disenchant.FindNextSlot(selectedItem.id, selectedItem.bound, skipB, skipS)

    if (not bag or not slot) and ignoreLastSlot then
        bag, slot = RDL_Disenchant.FindNextSlot(selectedItem.id, selectedItem.bound, nil, nil)
    end

    if not bag or not slot then
        targetRemaining = 0
        waitingBagUpdate = false
        movingFromBank = false
        lastBag, lastSlot = nil, nil
        ui.execFrame:Hide()
        print("|cff00ccff[Reinos de leyenda]|r Desencantamiento masivo completado.")
        return
    end

    if bag == -1 or bag >= 5 then
        local destBag, destSlot = FindFreePlayerBagSlot()
        if not destBag or not destSlot then
            targetRemaining = 0
            waitingBagUpdate = false
            movingFromBank = false
            lastBag, lastSlot = nil, nil
            ui.execFrame:Hide()
            print("|cffff5555[Reinos de leyenda]|r Necesitas al menos 1 hueco libre en tus bolsas para sacar objetos del banco.")
            return
        end

        movingFromBank = true
        lastBag, lastSlot = destBag, destSlot
        ui.execStatus:SetText("Sacando del banco: " .. selectedItem.name)
        ui.actionBtn:SetText("Moviendo...")
        ui.actionBtn:Disable()
        ui.execFrame:Show()

        ClearCursor()
        PickupContainerItem(bag, slot)
        PickupContainerItem(destBag, destSlot)
        return
    end

    movingFromBank = false
    SetReadyButton(bag, slot)
end

function RDL_Disenchant.BeginExecution(itemData, count)
    if not IsSpellKnown(RDL_Disenchant.GetSpellID()) then
        print("|cffff5555[Reinos de leyenda]|r Tu personaje no conoce Desencantar.")
        return
    end
    selectedItem = itemData
    targetTotal = math.min(count, itemData.count)
    targetRemaining = targetTotal
    lastBag, lastSlot = nil, nil
    waitingBagUpdate = false
    movingFromBank = false
    ui.selFrame:Hide()
    ui.execFrame:ClearAllPoints()
    ui.execFrame:SetPoint("TOPLEFT", RDL_GUI, "TOPRIGHT", 8, -44)
    PrepareNext(false)
end

function RDL_Disenchant.RefreshList()
    filteredCache = RDL_Disenchant.GetFilteredItems()
    local total = #filteredCache
    FauxScrollFrame_Update(ui.scroll, total, 9, 24)
    local offset = FauxScrollFrame_GetOffset(ui.scroll)

    for i = 1, 9 do
        local idx = offset + i
        local b = ui.rows[i]
        if idx <= total then
            local it = filteredCache[idx]
            b.itemData = it
            b.icon:SetTexture(it.icon)
            local r, g, bl = GetItemQualityColor(it.quality)
            b.text:SetTextColor(r, g, bl)
            local selMark = (selectedItem and selectedItem.key == it.key) and "|cff00ccff> |r" or ""
            local boundTag = it.bound and " |cffff5555[L]|r" or ""
            local bankTag = (it.bankCount and it.bankCount > 0) and (" |cff66ccff[B:" .. it.bankCount .. "]|r") or ""
            b.text:SetText(selMark .. it.name .. " |cffaaaaaa(" .. it.iLvl .. ")|r" .. boundTag .. bankTag .. " |cffffffffx" .. it.count .. "|r")
            b:Show()
        else
            b:Hide()
        end
    end
end

function RDL_Disenchant.ToggleSelector()
    if ui.selFrame:IsShown() then ui.selFrame:Hide() else RDL_Disenchant.RefreshList(); ui.selFrame:Show() end
end

local deEv = CreateFrame("Frame")
local deTimer = CreateFrame("Frame")
deEv:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
deEv:RegisterEvent("BAG_UPDATE")
deEv:RegisterEvent("LOOT_OPENED")
deEv:RegisterEvent("BANKFRAME_OPENED")
deEv:RegisterEvent("BANKFRAME_CLOSED")

local function SchedulePrepareNext(delay, ignoreLastSlot)
    local elapsed = 0
    deTimer:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            if ui.execFrame:IsShown() then
                PrepareNext(ignoreLastSlot)
            end
        end
    end)
end

deEv:SetScript("OnEvent", function(_, ev, unit, spellName)
    if ev == "LOOT_OPENED" then
        if ui.execFrame:IsShown() and LootFrame then
            LootFrame:ClearAllPoints()
            LootFrame:SetPoint("TOP", ui.execFrame, "BOTTOM", 0, -6)
        end
    elseif ev == "BANKFRAME_OPENED" or ev == "BANKFRAME_CLOSED" then
        if ui.selFrame:IsShown() then
            RDL_Disenchant.RefreshList()
        end
    elseif ev == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local deName = GetSpellInfo(RDL_Disenchant.GetSpellID())
        if deName and spellName == deName and targetRemaining > 0 then
            targetRemaining = targetRemaining - 1
            waitingBagUpdate = true
            ui.actionBtn:Disable()
            ui.actionBtn:SetText("Procesando...")
            SchedulePrepareNext(0.45, true)
        end
    elseif ev == "BAG_UPDATE" then
        if ui.selFrame:IsShown() then
            RDL_Disenchant.RefreshList()
        end
        if ui.execFrame:IsShown() then
            if movingFromBank and lastBag and lastSlot then
                if GetContainerItemID(lastBag, lastSlot) == selectedItem.id then
                    movingFromBank = false
                    SetReadyButton(lastBag, lastSlot)
                end
            elseif waitingBagUpdate then
                waitingBagUpdate = false
                SchedulePrepareNext(0.2, false)
            end
        end
    end
end)
