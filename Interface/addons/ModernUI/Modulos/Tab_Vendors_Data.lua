local addonName, NS = ...

local VF = {
    active = false,
    merchantOpen = false,
    hookOverwrite = false,
    indexLookup = {},
    maxIndex = 0,
    filters = {
        usable = false,
        affordable = false,
        unknownOnly = false,
        qualities = {},
        equipLocs = {},
        types = {},
        statsInc = {},
        statsEx = {},
    },
    seen = {
        qualities = {},
        equipLocs = {},
        types = {},
        stats = {},
    }
}
NS.VendorFilter = VF

local scanTip = CreateFrame("GameTooltip", "ModernUI_VendorScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
local knownCache = setmetatable({}, { __mode = "kv" })

local function IsItemAlreadyKnown(link)
    if not link then return false end
    if knownCache[link] ~= nil then return knownCache[link] end
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    for i = 1, scanTip:NumLines() do
        local left = _G["ModernUI_VendorScanTooltipTextLeft" .. i]
        if left and left:GetText() == ITEM_SPELL_KNOWN then
            knownCache[link] = true
            return true
        end
    end
    knownCache[link] = false
    return false
end

local function IsItemAffordable(rawIndex, price, extendedCost)
    if price and price > GetMoney() then
        return false
    end
    if extendedCost then
        local honorPoints, arenaPoints, itemCount = VF.GetMerchantItemCostInfo_old(rawIndex)
        if (honorPoints and honorPoints > GetHonorCurrency()) or (arenaPoints and arenaPoints > GetArenaCurrency()) then
            return false
        end
        if itemCount and itemCount > 0 then
            for id = 1, itemCount do
                local _, itemValue, itemLink = VF.GetMerchantItemCostItem_old(rawIndex, id)
                if itemLink and itemValue and itemValue > GetItemCount(itemLink) then
                    return false
                end
            end
        end
    end
    return true
end

local tempStats = {}
local function ShouldFilterItem(rawIndex, link)
    local _, _, price, _, _, isUsable, extendedCost = VF.GetMerchantItemInfo_old(rawIndex)

    if VF.filters.usable and not isUsable then
        return true
    end
    if VF.filters.affordable and not IsItemAffordable(rawIndex, price, extendedCost) then
        return true
    end
    if not link then return false end

    if VF.filters.unknownOnly and IsItemAlreadyKnown(link) then
        return true
    end

    local _, _, rarity, _, _, itemType, _, _, itemEquipLoc = GetItemInfo(link)

    if next(VF.filters.qualities) and rarity ~= nil and not VF.filters.qualities[rarity] then
        return true
    end
    if next(VF.filters.equipLocs) and (not itemEquipLoc or not VF.filters.equipLocs[itemEquipLoc]) then
        return true
    end
    if next(VF.filters.types) and (not itemType or not VF.filters.types[itemType]) then
        return true
    end

    if next(VF.filters.statsEx) or next(VF.filters.statsInc) then
        wipe(tempStats)
        GetItemStats(link, tempStats)
        for stat in pairs(tempStats) do
            if VF.filters.statsEx[stat] then
                return true
            end
        end
        if next(VF.filters.statsInc) then
            local hasWanted = false
            for stat in pairs(tempStats) do
                if VF.filters.statsInc[stat] then
                    hasWanted = true
                    break
                end
            end
            if not hasWanted then return true end
        end
    end

    return false
end

function NS.RebuildVendorLookup()
    if not VF.active or not VF.GetMerchantNumItems_old then return end
    VF.merchantOpen = true
    VF.indexLookup = {}
    VF.maxIndex = 0

    wipe(VF.seen.qualities)
    wipe(VF.seen.equipLocs)
    wipe(VF.seen.types)
    wipe(VF.seen.stats)

    local totalRaw = VF.GetMerchantNumItems_old()
    local anyFiltered = false

    for i = 1, totalRaw do
        local link = VF.GetMerchantItemLink_old(i)
        if link then
            local _, _, rarity, _, _, itemType, _, _, itemEquipLoc = GetItemInfo(link)
            if rarity ~= nil then VF.seen.qualities[rarity] = true end
            if itemEquipLoc and _G[itemEquipLoc] then VF.seen.equipLocs[itemEquipLoc] = true end
            if itemType then VF.seen.types[itemType] = true end
            wipe(tempStats)
            GetItemStats(link, tempStats)
            for stat in pairs(tempStats) do
                if _G[stat] then VF.seen.stats[stat] = true end
            end

            if ShouldFilterItem(i, link) then
                anyFiltered = true
            else
                VF.maxIndex = VF.maxIndex + 1
                VF.indexLookup[VF.maxIndex] = i
            end
        else
            VF.maxIndex = VF.maxIndex + 1
            VF.indexLookup[VF.maxIndex] = i
        end
    end

    if VF.UpdateBarState then
        VF.UpdateBarState(anyFiltered)
    end
end

function NS.ResetAllVendorFilters()
    VF.filters.usable = false
    VF.filters.affordable = false
    VF.filters.unknownOnly = false
    wipe(VF.filters.qualities)
    wipe(VF.filters.equipLocs)
    wipe(VF.filters.types)
    wipe(VF.filters.statsInc)
    wipe(VF.filters.statsEx)
end

function NS.RefreshVendorUI()
    NS.RebuildVendorLookup()
    if MerchantFrame_Update then
        MerchantFrame_Update()
    end
end

function NS.InstallMerchantHooks()
    if VF.hooksInstalled then return end
    VF.hooksInstalled = true

    VF.GetMerchantNumItems_old      = GetMerchantNumItems
    VF.GetMerchantItemLink_old      = GetMerchantItemLink
    VF.BuyMerchantItem_old          = BuyMerchantItem
    VF.GetMerchantItemCostInfo_old  = GetMerchantItemCostInfo
    VF.GetMerchantItemCostItem_old  = GetMerchantItemCostItem
    VF.GetMerchantItemInfo_old      = GetMerchantItemInfo
    VF.GetMerchantItemMaxStack_old  = GetMerchantItemMaxStack
    VF.PickupMerchantItem_old     = PickupMerchantItem
    VF.ShowMerchantSellCursor_old   = ShowMerchantSellCursor

    local function ResolveRawIndex(index)
        if not index then return nil end
        if not next(VF.indexLookup) then
            NS.RebuildVendorLookup()
        end
        return VF.indexLookup[index]
    end

    GetMerchantNumItems = function()
        if not VF.active then return VF.GetMerchantNumItems_old() end
        VF.hookOverwrite = false
        NS.RebuildVendorLookup()
        return VF.maxIndex
    end

    GetMerchantItemLink = function(index)
        if not VF.active or VF.hookOverwrite then return VF.GetMerchantItemLink_old(index) end
        local raw = ResolveRawIndex(index)
        return raw and VF.GetMerchantItemLink_old(raw) or nil
    end

    BuyMerchantItem = function(index, qty)
        if not VF.active then return VF.BuyMerchantItem_old(index, qty) end
        local raw = ResolveRawIndex(index) or index
        return VF.BuyMerchantItem_old(raw, qty)
    end

    GetMerchantItemCostInfo = function(index)
        if not VF.active or VF.hookOverwrite then return VF.GetMerchantItemCostInfo_old(index) end
        local raw = ResolveRawIndex(index) or index
        return VF.GetMerchantItemCostInfo_old(raw)
    end

    GetMerchantItemCostItem = function(index, itemIndex)
        if not VF.active or VF.hookOverwrite then return VF.GetMerchantItemCostItem_old(index, itemIndex) end
        local raw = ResolveRawIndex(index) or index
        return VF.GetMerchantItemCostItem_old(raw, itemIndex)
    end

    GetMerchantItemInfo = function(index)
        if not VF.active or VF.hookOverwrite then return VF.GetMerchantItemInfo_old(index) end
        local raw = ResolveRawIndex(index)
        if not raw then
            return "", nil, 0, 1, -1, false, false
        end
        return VF.GetMerchantItemInfo_old(raw)
    end

    GetMerchantItemMaxStack = function(index)
        if not VF.active or VF.hookOverwrite then return VF.GetMerchantItemMaxStack_old(index) end
        local raw = ResolveRawIndex(index) or index
        return VF.GetMerchantItemMaxStack_old(raw)
    end

    PickupMerchantItem = function(index)
        if not VF.active then return VF.PickupMerchantItem_old(index) end
        local raw = ResolveRawIndex(index) or index
        return VF.PickupMerchantItem_old(raw)
    end

    ShowMerchantSellCursor = function(index)
        if not VF.active then return VF.ShowMerchantSellCursor_old(index) end
        local raw = ResolveRawIndex(index) or index
        return VF.ShowMerchantSellCursor_old(raw)
    end

    local hookedTips = {}
    local function HookAllTooltips()
        local frame = EnumerateFrames()
        while frame do
            if string.lower(frame:GetObjectType()) == "gametooltip" and not hookedTips[frame] and frame.SetMerchantItem then
                hookedTips[frame] = true
                frame.SetMerchantItem_old = frame.SetMerchantItem
                frame.SetMerchantItem = function(self, i, ...)
                    if not VF.active then return self:SetMerchantItem_old(i, ...) end
                    VF.hookOverwrite = true
                    self:SetMerchantItem_old(ResolveRawIndex(i) or i, ...)
                    VF.hookOverwrite = false
                end
            end
            frame = EnumerateFrames(frame)
        end
    end
    MerchantFrame:HookScript("OnShow", HookAllTooltips)
    HookAllTooltips()
end
