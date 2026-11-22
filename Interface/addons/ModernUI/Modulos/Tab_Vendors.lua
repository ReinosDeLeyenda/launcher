local addonName, NS = ...

function NS.InitVendorsTheme()
    if not MerchantFrame then return end

    local VF = NS.VendorFilter
    if VF then
        VF.active = true
        NS.InstallMerchantHooks()
    end

    NS.CleanFrameTextures(MerchantFrame)
    NS.ApplyIceBackdrop(MerchantFrame, 0.95, 0.05, 0.14, 0.24, 16, 4)
    NS.AddTopGlow(MerchantFrame, 45, 0.35, 4)

    if MerchantFramePortrait then
        MerchantFramePortrait:Hide()
    end

    for i = 1, 2 do
        local tab = _G["MerchantFrameTab" .. i]
        if tab then
            NS.CleanFrameTextures(tab)
            NS.ApplyIceBackdrop(tab, 0.90, 0.05, 0.14, 0.24, 8, 1)
        end
    end

    for i = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
        local itemFrame = _G["MerchantItem" .. i]
        local itemBtn = _G["MerchantItem" .. i .. "ItemButton"]
        if itemFrame then
            NS.CleanFrameTextures(itemFrame)
            NS.ApplyIceBackdrop(itemFrame, 0.82, 0.04, 0.11, 0.20, 8, 1)
        end
        if itemBtn then
            local icon = _G["MerchantItem" .. i .. "ItemButtonIconTexture"]
            if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        end
    end

    for _, slotBtn in ipairs({ MerchantRepairItemButton, MerchantRepairAllButton, MerchantGuildBankRepairButton, MerchantBuyBackItemItemButton }) do
        if slotBtn then
            NS.ApplyIceBackdrop(slotBtn, 0.85, 0.05, 0.14, 0.24, 8, 1)
        end
    end

    if NS.BuildVendorFilterBar then
        NS.BuildVendorFilterBar()
    end

    MerchantFrame:HookScript("OnShow", function()
        if VF then
            VF.merchantOpen = true
            NS.RebuildVendorLookup()
        end
    end)

    MerchantFrame:HookScript("OnHide", function()
        if VF then
            VF.merchantOpen = false
        end
        CloseDropDownMenus()
    end)
end
