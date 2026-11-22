local addonName, NS = ...

local function UpdateTooltipBorderByQuality(tooltip)
    NS.ApplyIceBackdrop(tooltip, 0.94)
    NS.AddTopGlow(tooltip, 22, 0.35)

    if tooltip.GetItem then
        local _, itemLink = tooltip:GetItem()
        if itemLink then
            local _, _, rarity = GetItemInfo(itemLink)
            if rarity and rarity >= 2 then
                local r, g, b = GetItemQualityColor(rarity)
                tooltip:SetBackdropBorderColor(r, g, b, 1.0)
                return
            end
        end
    end
    local bd = NS.Theme.BD
    tooltip:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1.0)
end

function NS.InitTooltipsTheme()
    local tooltips = {
        GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3,
        WorldMapTooltip, WorldMapCompareTooltip1, WorldMapCompareTooltip2, WorldMapCompareTooltip3,
        FriendsTooltip, DropDownList1MenuBackdrop, DropDownList2MenuBackdrop
    }
    for _, tt in ipairs(tooltips) do
        if tt then
            UpdateTooltipBorderByQuality(tt)
            tt:HookScript("OnShow", UpdateTooltipBorderByQuality)
        end
    end

    if GameTooltipStatusBar then
        GameTooltipStatusBar:SetStatusBarTexture("Interface\\ChatFrame\\ChatFrameBackground")
        GameTooltipStatusBar:SetStatusBarColor(0.25, 0.78, 1.0)
        GameTooltipStatusBar:ClearAllPoints()
        GameTooltipStatusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 3, -2)
        GameTooltipStatusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -3, -2)
        GameTooltipStatusBar:SetHeight(6)
    end

    if GameTooltip_SetDefaultAnchor then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", UpdateTooltipBorderByQuality)
    end
end
