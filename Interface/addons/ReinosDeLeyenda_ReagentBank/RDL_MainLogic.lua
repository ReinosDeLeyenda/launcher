local gui = RDL_GUI
local filteredIndices = {}
local craftableCache = {}
local reagentIDCache = {}

local COLORS = {
    optimal = {1.0, 0.5, 0.25},
    medium  = {1.0, 1.0, 0.0},
    easy    = {0.25, 0.75, 0.25},
    trivial = {0.5, 0.5, 0.5},
    header  = {0.48, 0.88, 1.0} -- Encabezados en azul hielo
}

local function GetCachedReagentID(skillIdx, reagentIdx)
    local link = GetTradeSkillReagentItemLink(skillIdx, reagentIdx)
    if not link then return nil end
    local id = reagentIDCache[link]
    if not id then
        id = tonumber(link:match("item:(%d+)")) or 0
        reagentIDCache[link] = id
    end
    return id > 0 and id or nil
end

local function ComputeMaxCraftable(skillIdx)
    local numReagents = GetTradeSkillNumReagents(skillIdx)
    if not numReagents or numReagents == 0 then return 0 end
    local maxC = 999
    for r = 1, numReagents do
        local _, _, req, have = GetTradeSkillReagentInfo(skillIdx, r)
        local itemID = GetCachedReagentID(skillIdx, r)
        local tot = math.max(have or 0, RDL_Core.TotalCount(itemID))
        if req and req > 0 then
            local can = math.floor(tot / req)
            if can <= 0 then
                return 0
            end
            if can < maxC then maxC = can end
        end
    end
    return maxC < 999 and maxC or 0
end

gui.itemIcon:SetScript("OnEnter", function(self)
    local sel = GetTradeSkillSelectionIndex()
    if sel and sel > 0 then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetTradeSkillItem(sel)
        GameTooltip:Show()
    end
end)
gui.itemIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
gui.itemIcon:SetScript("OnClick", function()
    local sel = GetTradeSkillSelectionIndex()
    if sel and sel > 0 and IsModifiedClick("CHATLINK") then
        local link = GetTradeSkillItemLink(sel) or GetTradeSkillRecipeLink(sel)
        if link then ChatEdit_InsertLink(link) end
    end
end)

for i = 1, 8 do
    local rb = gui.reagentRows[i]
    rb:SetScript("OnEnter", function(self)
        local sel = GetTradeSkillSelectionIndex()
        if not sel or sel <= 0 or not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetTradeSkillItem(sel, i)
        local b, p, v = RDL_Core.GetBreakdownCounts(self.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff7ce0ffInventario Reinos de leyenda:|r")
        GameTooltip:AddDoubleLine("  Mochila:", tostring(b), 0.9, 0.9, 0.9, 1, 1, 1)
        GameTooltip:AddDoubleLine("  Banco personal:", tostring(p), 0.9, 0.9, 0.9, 0.4, 0.85, 1)
        GameTooltip:AddDoubleLine("  Boveda de Componentes:", tostring(v), 0.9, 0.9, 0.9, 0.2, 1, 0.65)
        GameTooltip:Show()
    end)
    rb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rb:SetScript("OnClick", function()
        local sel = GetTradeSkillSelectionIndex()
        if sel and sel > 0 and IsModifiedClick("CHATLINK") then
            local link = GetTradeSkillReagentItemLink(sel, i)
            if link then ChatEdit_InsertLink(link) end
        end
    end)
end

for i = 1, 17 do
    gui.rowButtons[i]:SetScript("OnClick", function(self)
        if not self.skillIndex then return end
        if IsModifiedClick("CHATLINK") then
            local link = GetTradeSkillItemLink(self.skillIndex) or GetTradeSkillRecipeLink(self.skillIndex)
            if link then ChatEdit_InsertLink(link) end
            return
        end
        local _, st, _, isExp = GetTradeSkillInfo(self.skillIndex)
        if st == "header" then
            if isExp then CollapseTradeSkillSubClass(self.skillIndex) else ExpandTradeSkillSubClass(self.skillIndex) end
        else
            SelectTradeSkill(self.skillIndex)
            RDL_MainFrame_UpdateDetails()
            RDL_MainFrame_RenderRows()
        end
    end)
end

gui.createBtn:SetScript("OnClick", function()
    local sel = GetTradeSkillSelectionIndex()
    local n = math.max(1, tonumber(gui.qtyBox:GetText()) or 1)
    if sel and sel > 0 then RDL_Core.Craft(sel, n) end
    gui.qtyBox:ClearFocus()
end)

gui.createAllBtn:SetScript("OnClick", function()
    local sel = GetTradeSkillSelectionIndex()
    if not sel or sel <= 0 then return end
    local maxC = craftableCache[sel] or ComputeMaxCraftable(sel)
    local n = (maxC > 0) and maxC or 1
    gui.qtyBox:SetText(tostring(n))
    RDL_Core.Craft(sel, n)
    gui.qtyBox:ClearFocus()
end)

function RDL_MainFrame_UpdateDetails()
    local sel = GetTradeSkillSelectionIndex()
    if not sel or sel <= 0 then return end
    local name, st, _, _, altVerb = GetTradeSkillInfo(sel)
    if st == "header" then return end

    gui.itemTitle:SetText(name or "")
    gui.itemIcon.tex:SetTexture(GetTradeSkillIcon(sel))
    gui.createBtn:SetText(altVerb or "Crear")

    local maxC = 999
    local numReq = GetTradeSkillNumReagents(sel)
    for i = 1, 8 do
        local rb = gui.reagentRows[i]
        if i <= numReq then
            local rName, rTex, req, have = GetTradeSkillReagentInfo(sel, i)
            local itemID = GetCachedReagentID(sel, i)
            local tot = math.max(have or 0, RDL_Core.TotalCount(itemID))
            rb.itemID = itemID
            rb.icon:SetTexture(rTex)
            rb.name:SetText(rName or "")
            rb.count:SetText(tot .. " / " .. (req or 1))
            local ok = tot >= (req or 1)
            rb.name:SetTextColor(ok and 0.9 or 0.5, ok and 0.97 or 0.5, ok and 1 or 0.5)
            rb.count:SetTextColor(ok and 0.45 or 1, ok and 0.95 or 0.3, ok and 1 or 0.3)
            rb.icon:SetVertexColor(ok and 1 or 0.5, ok and 1 or 0.5, ok and 1 or 0.5)
            if req and req > 0 then maxC = math.min(maxC, math.floor(tot / req)) end
            rb:Show()
        else
            rb:Hide()
        end
    end

    if maxC > 0 and maxC < 999 then
        gui.itemSub:SetText("|cff66e5ffPuedes fabricar: " .. maxC .. "|r")
        gui.createAllBtn:SetText("Crear todos [" .. maxC .. "]")
    else
        gui.itemSub:SetText("|cffff5555Faltan materiales|r")
        gui.createAllBtn:SetText("Crear todos")
    end
end

function RDL_MainFrame_RenderRows()
    local total = #filteredIndices
    FauxScrollFrame_Update(gui.scrollFrame, total, 17, 20)
    local offset = FauxScrollFrame_GetOffset(gui.scrollFrame)
    local sel = GetTradeSkillSelectionIndex()

    for i = 1, 17 do
        local idx = offset + i
        local row = gui.rowButtons[i]
        if idx <= total then
            local skillIdx = filteredIndices[idx]
            local name, st, _, isExp = GetTradeSkillInfo(skillIdx)
            row.skillIndex = skillIdx
            local col = COLORS[st] or COLORS.trivial
            row.text:SetTextColor(unpack(col))
            if st == "header" then
                row.text:SetText((isExp and "- " or "+ ") .. (name or ""))
            else
                local maxC = craftableCache[skillIdx] or 0
                local prefix = (skillIdx == sel) and "|cff7ce0ff> |r" or "   "
                local suffix = (maxC > 0) and (" |cff66e5ff[" .. maxC .. "]|r") or ""
                row.text:SetText(prefix .. (name or "") .. suffix)
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

function RDL_MainFrame_UpdateList()
    wipe(filteredIndices)
    wipe(craftableCache)
    RDL_Core.ClearCountCache()

    local onlyMats = gui.onlyMats:GetChecked()
    local numSkills = GetNumTradeSkills()
    local pendingHeader = nil

    for i = 1, numSkills do
        local _, st, _, isExp = GetTradeSkillInfo(i)
        if st == "header" then
            if not onlyMats then
                table.insert(filteredIndices, i)
            elseif not isExp then
                table.insert(filteredIndices, i)
                pendingHeader = nil
            else
                pendingHeader = i
            end
        else
            local maxC = ComputeMaxCraftable(i)
            craftableCache[i] = maxC
            if not onlyMats or maxC > 0 then
                if pendingHeader then
                    table.insert(filteredIndices, pendingHeader)
                    pendingHeader = nil
                end
                table.insert(filteredIndices, i)
            end
        end
    end

    RDL_MainFrame_RenderRows()
end

gui.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 20, RDL_MainFrame_RenderRows)
end)

function RDL_MainFrame_Refresh()
    local pName, rank, maxRank = GetTradeSkillLine()
    if pName and pName ~= "UNKNOWN" then
        gui.subTitle:SetText(pName .. " (" .. (rank or 0) .. " / " .. (maxRank or 0) .. ")")
    end
    RDL_ProfList.RenderTabs(gui)
    RDL_MainFrame_UpdateList()
    RDL_MainFrame_UpdateDetails()
end
