local f = CreateFrame("Frame")
local refreshTimer = CreateFrame("Frame")
local refreshPending = false

local function QueueRefresh()
    if refreshPending or not RDL_GUI:IsShown() then return end
    refreshPending = true
    local elapsed = 0
    refreshTimer:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.08 then
            self:SetScript("OnUpdate", nil)
            refreshPending = false
            if RDL_GUI:IsShown() then
                RDL_MainFrame_Refresh()
            end
        end
    end)
end

local events = {
    "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "CHAT_MSG_ADDON",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE",
    "SKILL_LINES_CHANGED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED",
    "BAG_UPDATE",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED"
}
for _, e in ipairs(events) do f:RegisterEvent(e) end

RDL_GUI:HookScript("OnHide", function()
    if RDL_DE_UI then
        if RDL_DE_UI.selFrame then RDL_DE_UI.selFrame:Hide() end
        if RDL_DE_UI.execFrame and RDL_DE_UI.cancelBtn then
            RDL_DE_UI.cancelBtn:Click()
        elseif RDL_DE_UI.execFrame then
            RDL_DE_UI.execFrame:Hide()
        end
    end
end)

f:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4)
    if ev == "PLAYER_ENTERING_WORLD" or ev == "PARTY_MEMBERS_CHANGED" or ev == "RAID_ROSTER_UPDATE" then
        RDL_Core.BroadcastVersion()
    elseif ev == "CHAT_MSG_ADDON" then
        RDL_Core.OnAddonMessage(a1, a2, a3, a4)
    elseif ev == "TRADE_SKILL_SHOW" then
        if TradeSkillFrame then
            TradeSkillFrame:SetAlpha(0)
            TradeSkillFrame:EnableMouse(false)
            TradeSkillFrame:ClearAllPoints()
            TradeSkillFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
        end
        RDL_GUI:Show()
        RDL_MainFrame_Refresh()
    elseif ev == "TRADE_SKILL_CLOSE" then
        RDL_GUI:Hide()
    elseif ev == "TRADE_SKILL_UPDATE" then
        QueueRefresh()
    elseif ev == "SKILL_LINES_CHANGED" and RDL_GUI:IsShown() then
        RDL_ProfList.RenderTabs(RDL_GUI)
    elseif ev == "BANKFRAME_OPENED" then
        RDL_Core.SetBankOpen(true)
        RDL_Core.ScanBank()
        QueueRefresh()
    elseif ev == "BANKFRAME_CLOSED" then
        RDL_Core.ScanBank()
        RDL_Core.SetBankOpen(false)
    elseif ev == "GUILDBANKFRAME_OPENED" then
        RDL_Core.SetGuildBankOpen(true)
        RDL_Core.ScanReagentVault()
        QueueRefresh()
    elseif ev == "GUILDBANKFRAME_CLOSED" then
        RDL_Core.ScanReagentVault()
        RDL_Core.SetGuildBankOpen(false)
    elseif ev == "GUILDBANKBAGSLOTS_CHANGED" then
        RDL_Core.ScanReagentVault()
        QueueRefresh()
    elseif ev == "BAG_UPDATE" then
        RDL_Core.TryStoreCraftedGearInBank()
        RDL_Core.ScanBank()
        QueueRefresh()
    elseif ev == "UNIT_SPELLCAST_SUCCEEDED" and a1 == "player" then
        RDL_Core.OnSpellSucceeded(a2)
        QueueRefresh()
    elseif (ev == "UNIT_SPELLCAST_FAILED" or ev == "UNIT_SPELLCAST_INTERRUPTED") and a1 == "player" then
        RDL_Core.OnSpellStopped(a2)
    end
end)
