local addonName, NS = ...

function NS.BuildVendorFilterBar()
    local VF = NS.VendorFilter
    if not VF or not MerchantFrame or MerchantFrame._mcuiFilterBar then return end

    local bar = CreateFrame("Frame", "ModernUI_VendorFilterBar", MerchantFrame)
    bar:SetHeight(24)
    bar:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 16, -34)
    bar:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -34, -34)
    NS.ApplyIceBackdrop(bar, 0.90, 0.04, 0.12, 0.22, 8, 1)
    MerchantFrame._mcuiFilterBar = bar

    local function MakeTogglePill(parent, text, width, getter, setter)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, 18)
        NS.ApplyIceBackdrop(btn, 0.85, 0.06, 0.18, 0.32, 6, 1)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("CENTER")
        btn.label:SetText(text)

        function btn:UpdateVisual()
            if getter() then
                self:SetBackdropColor(0.16, 0.48, 0.78, 0.95)
                self:SetBackdropBorderColor(0.45, 0.88, 1.0, 1)
                self.label:SetTextColor(1, 1, 1)
            else
                self:SetBackdropColor(0.05, 0.15, 0.26, 0.85)
                self:SetBackdropBorderColor(0.25, 0.55, 0.80, 0.6)
                self.label:SetTextColor(0.65, 0.85, 1.0)
            end
        end

        btn:SetScript("OnClick", function(self)
            setter(not getter())
            self:UpdateVisual()
            NS.RefreshVendorUI()
        end)
        btn:UpdateVisual()
        return btn
    end

    local btnUsable = MakeTogglePill(bar, "Usable", 56,
        function() return VF.filters.usable end,
        function(v) VF.filters.usable = v end)
    btnUsable:SetPoint("LEFT", bar, "LEFT", 6, 0)

    local btnAfford = MakeTogglePill(bar, "Comprable", 72,
        function() return VF.filters.affordable end,
        function(v) VF.filters.affordable = v end)
    btnAfford:SetPoint("LEFT", btnUsable, "RIGHT", 4, 0)

    local btnUnknown = MakeTogglePill(bar, "Sin aprender", 80,
        function() return VF.filters.unknownOnly end,
        function(v) VF.filters.unknownOnly = v end)
    btnUnknown:SetPoint("LEFT", btnAfford, "RIGHT", 4, 0)

    local dropMenu = CreateFrame("Frame", "ModernUI_VendorDropMenu", bar, "UIDropDownMenuTemplate")
    local info = {}

    dropMenu.initialize = function(self, level)
        if not level then return end
        wipe(info)
        info.keepShownOnClick = 1

        if level == 1 then
            info.isTitle = 1
            info.notCheckable = 1
            info.text = "|cff66ccffFiltros Avanzados|r"
            UIDropDownMenu_AddButton(info, level)

            info.isTitle = nil
            info.hasArrow = 1
            if next(VF.seen.qualities) then
                info.text = QUALITY
                info.value = "MCUI_QUALITY"
                UIDropDownMenu_AddButton(info, level)
            end
            if next(VF.seen.equipLocs) then
                info.text = ITEMSLOTTEXT
                info.value = "MCUI_EQUIPLOC"
                UIDropDownMenu_AddButton(info, level)
            end
            if next(VF.seen.types) then
                info.text = TYPE
                info.value = "MCUI_TYPE"
                UIDropDownMenu_AddButton(info, level)
            end
            if next(VF.seen.stats) then
                info.text = STAT_CATEGORY_ATTRIBUTES or "Estadísticas"
                info.value = "MCUI_STATS"
                UIDropDownMenu_AddButton(info, level)
            end

            info.hasArrow = nil
            info.notCheckable = 1
            info.text = "|cff4ade80Mostrar Todo|r"
            info.func = function()
                NS.ResetAllVendorFilters()
                CloseDropDownMenus()
                NS.RefreshVendorUI()
            end
            UIDropDownMenu_AddButton(info, level)

        elseif level == 2 then
            local val = UIDROPDOWNMENU_MENU_VALUE
            info.hasArrow = nil
            info.notCheckable = nil

            if val == "MCUI_QUALITY" then
                local sorted = {}
                for q in pairs(VF.seen.qualities) do table.insert(sorted, q) end
                table.sort(sorted)
                for _, q in ipairs(sorted) do
                    local _, _, _, hex = GetItemQualityColor(q)
                    info.text = (hex or "|cffffffff") .. (_G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q))
                    info.checked = VF.filters.qualities[q]
                    info.func = function()
                        VF.filters.qualities[q] = not VF.filters.qualities[q] or nil
                        NS.RefreshVendorUI()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end

            elseif val == "MCUI_EQUIPLOC" then
                local sorted = {}
                for loc in pairs(VF.seen.equipLocs) do table.insert(sorted, loc) end
                table.sort(sorted, function(a, b) return (_G[a] or a) < (_G[b] or b) end)
                for _, loc in ipairs(sorted) do
                    info.text = _G[loc] or loc
                    info.checked = VF.filters.equipLocs[loc]
                    info.func = function()
                        VF.filters.equipLocs[loc] = not VF.filters.equipLocs[loc] or nil
                        NS.RefreshVendorUI()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end

            elseif val == "MCUI_TYPE" then
                local sorted = {}
                for t in pairs(VF.seen.types) do table.insert(sorted, t) end
                table.sort(sorted)
                for _, t in ipairs(sorted) do
                    info.text = t
                    info.checked = VF.filters.types[t]
                    info.func = function()
                        VF.filters.types[t] = not VF.filters.types[t] or nil
                        NS.RefreshVendorUI()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end

            elseif val == "MCUI_STATS" then
                local sorted = {}
                for s in pairs(VF.seen.stats) do table.insert(sorted, s) end
                table.sort(sorted, function(a, b) return (_G[a] or a) < (_G[b] or b) end)
                for _, s in ipairs(sorted) do
                    info.text = _G[s] or s
                    info.checked = VF.filters.statsInc[s]
                    info.func = function()
                        VF.filters.statsInc[s] = not VF.filters.statsInc[s] or nil
                        NS.RefreshVendorUI()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end

    local btnMore = CreateFrame("Button", nil, bar)
    btnMore:SetSize(64, 18)
    btnMore:SetPoint("LEFT", btnUnknown, "RIGHT", 4, 0)
    NS.ApplyIceBackdrop(btnMore, 0.85, 0.08, 0.24, 0.42, 6, 1)
    btnMore.label = btnMore:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnMore.label:SetPoint("CENTER")
    btnMore.label:SetText("|cff7dd3fcMás +|r")
    btnMore:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, dropMenu, self, 0, 0)
    end)

    local btnReset = CreateFrame("Button", nil, bar)
    btnReset:SetSize(20, 18)
    btnReset:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    NS.ApplyIceBackdrop(btnReset, 0.85, 0.08, 0.24, 0.42, 6, 1)
    btnReset.label = btnReset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnReset.label:SetPoint("CENTER")
    btnReset.label:SetText("X")
    btnReset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Restablecer todos los filtros")
        GameTooltip:Show()
    end)
    btnReset:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btnReset:SetScript("OnClick", function()
        NS.ResetAllVendorFilters()
        CloseDropDownMenus()
        NS.RefreshVendorUI()
    end)

    function VF.UpdateBarState(anyFiltered)
        btnUsable:UpdateVisual()
        btnAfford:UpdateVisual()
        btnUnknown:UpdateVisual()
        if anyFiltered then
            btnReset.label:SetTextColor(1, 0.35, 0.35)
        else
            btnReset.label:SetTextColor(0.35, 0.90, 0.45)
        end
    end
end
