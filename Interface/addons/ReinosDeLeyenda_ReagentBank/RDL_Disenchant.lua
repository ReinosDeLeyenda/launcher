RDL_Disenchant = {}

local DE_SPELL_ID = 13262
local scanTip = CreateFrame("GameTooltip", "RDL_DEScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

RDL_Disenchant.Filters = {
    green = true,
    blue = true,
    epic = false,
    allowBound = false,
    minLvl = 1,
    maxLvl = 300,
    sortBy = "count_desc"
}

local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }

local function IsBagItemSoulbound(bag, slot)
    scanTip:ClearLines()
    scanTip:SetBagItem(bag, slot)
    for i = 2, scanTip:NumLines() do
        local line = _G["RDL_DEScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and (text == ITEM_SOULBOUND or text:find("Ligado") or text:find("Soulbound")) then
            return true
        end
    end
    return false
end

local function ProcessContainerSlot(bag, slot, grouped, list, flt, isBank)
    local link = GetContainerItemLink(bag, slot)
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    local name, _, quality, iLvl, _, itemType, _, _, equipLoc, texture = GetItemInfo(link)
    local isGear = (itemType == "Armor" or itemType == "Weapon" or itemType == "Armadura" or itemType == "Arma") and equipLoc ~= ""

    if itemID and isGear and quality and quality >= 2 and quality <= 4 then
        local passQual = (quality == 2 and flt.green) or (quality == 3 and flt.blue) or (quality == 4 and flt.epic)
        local level = iLvl or 1
        local passLvl = (level >= flt.minLvl and level <= flt.maxLvl)
        local bound = IsBagItemSoulbound(bag, slot)
        local passBound = flt.allowBound or (not bound)

        if passQual and passLvl and passBound then
            local key = itemID .. "_" .. (bound and "1" or "0")
            if not grouped[key] then
                grouped[key] = {
                    key = key, id = itemID, name = name or "", quality = quality,
                    iLvl = level, icon = texture, link = link, bound = bound,
                    count = 0, bagCount = 0, bankCount = 0
                }
                table.insert(list, grouped[key])
            end
            grouped[key].count = grouped[key].count + 1
            if isBank then
                grouped[key].bankCount = grouped[key].bankCount + 1
            else
                grouped[key].bagCount = grouped[key].bagCount + 1
            end
        end
    end
end

function RDL_Disenchant.GetFilteredItems()
    local grouped, list = {}, {}
    local flt = RDL_Disenchant.Filters
    local bankOpen = RDL_Core and RDL_Core.IsBankOpen and RDL_Core.IsBankOpen()

    -- 1. Escanear mochilas (0 a 4)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            ProcessContainerSlot(bag, slot, grouped, list, flt, false)
        end
    end

    -- 2. Escanear banco personal si esta abierto (-1 y bolsas 5 a 11)
    if bankOpen then
        for _, bag in ipairs(BANK_BAGS) do
            for slot = 1, GetContainerNumSlots(bag) do
                ProcessContainerSlot(bag, slot, grouped, list, flt, true)
            end
        end
    elseif RDL_BankCache then
        -- Si el banco esta cerrado, mostrar vista previa desde la cache
        for itemID, qty in pairs(RDL_BankCache) do
            if qty and qty > 0 then
                local name, link, quality, iLvl, _, itemType, _, _, equipLoc, texture = GetItemInfo(itemID)
                local isGear = (itemType == "Armor" or itemType == "Weapon" or itemType == "Armadura" or itemType == "Arma") and equipLoc ~= ""
                if isGear and quality and quality >= 2 and quality <= 4 then
                    local passQual = (quality == 2 and flt.green) or (quality == 3 and flt.blue) or (quality == 4 and flt.epic)
                    local level = iLvl or 1
                    local passLvl = (level >= flt.minLvl and level <= flt.maxLvl)
                    if passQual and passLvl then
                        local key = itemID .. "_0"
                        if not grouped[key] then
                            grouped[key] = {
                                key = key, id = itemID, name = name or "", quality = quality,
                                iLvl = level, icon = texture, link = link, bound = false,
                                count = 0, bagCount = 0, bankCount = 0
                            }
                            table.insert(list, grouped[key])
                        end
                        grouped[key].count = grouped[key].count + qty
                        grouped[key].bankCount = grouped[key].bankCount + qty
                    end
                end
            end
        end
    end

    -- Ordenación
    local mode = flt.sortBy or "count_desc"
    table.sort(list, function(a, b)
        if mode == "count_desc" then
            if a.count ~= b.count then return a.count > b.count end
        elseif mode == "count_asc" then
            if a.count ~= b.count then return a.count < b.count end
        elseif mode == "lvl_desc" then
            if a.iLvl ~= b.iLvl then return a.iLvl > b.iLvl end
        elseif mode == "lvl_asc" then
            if a.iLvl ~= b.iLvl then return a.iLvl < b.iLvl end
        end
        return a.name < b.name
    end)

    return list
end

function RDL_Disenchant.FindNextSlot(itemID, requireBound, skipBag, skipSlot)
    -- Primero busca en las mochilas (0 a 4)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if not (bag == skipBag and slot == skipSlot) then
                if GetContainerItemID(bag, slot) == itemID then
                    local _, _, locked = GetContainerItemInfo(bag, slot)
                    if not locked and IsBagItemSoulbound(bag, slot) == requireBound then
                        return bag, slot
                    end
                end
            end
        end
    end

    -- Si el banco esta abierto, busca tambien en el banco (-1 y bolsas 5 a 11)
    if RDL_Core and RDL_Core.IsBankOpen and RDL_Core.IsBankOpen() then
        for _, bag in ipairs(BANK_BAGS) do
            for slot = 1, GetContainerNumSlots(bag) do
                if not (bag == skipBag and slot == skipSlot) then
                    if GetContainerItemID(bag, slot) == itemID then
                        local _, _, locked = GetContainerItemInfo(bag, slot)
                        if not locked and IsBagItemSoulbound(bag, slot) == requireBound then
                            return bag, slot
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

function RDL_Disenchant.GetSpellID()
    return DE_SPELL_ID
end
