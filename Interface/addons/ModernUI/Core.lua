local addonName, NS = ...

NS.VERSION = GetAddOnMetadata(addonName, "Version") or "3.6"
NS.latestVersion = NS.VERSION
NS.versionOutdated = false
NS.versionNotified = false

function NS.CompareVersions(v1, v2)
    if not v1 or not v2 then return 0 end
    local p1, p2 = {}, {}
    for n in string.gmatch(tostring(v1), "(%d+)") do table.insert(p1, tonumber(n)) end
    for n in string.gmatch(tostring(v2), "(%d+)") do table.insert(p2, tonumber(n)) end
    local len = math.max(#p1, #p2)
    for i = 1, len do
        local a = p1[i] or 0
        local b = p2[i] or 0
        if a > b then return 1 end
        if a < b then return -1 end
    end
    return 0
end

NS.MODULES_LIST = {
    { id = "Character",    init = "InitCharacterTab" },
    { id = "Pets",         init = "InitPetsTab" },
    { id = "Reputation",   init = "InitReputationTab" },
    { id = "Skills",       init = "InitSkillsSync" },
    { id = "Tokens",       init = "InitTokensTab" },
    { id = "QuestLog",     init = "InitQuestLogTheme" },
    { id = "Interface",    init = "InitInterfaceTheme" },
    { id = "Achievements", init = "InitAchievementsTheme" },
    { id = "Bags",         init = "InitBagsTheme" },
    { id = "GuildBank",    init = "InitGuildBankTheme" },
    { id = "Loot",         init = "InitLootTheme" },
    { id = "Glyphs",       init = "InitGlyphsTheme" },
    { id = "SpellBook",    init = "InitSpellBookTheme" },
    { id = "Talents",      init = "InitTalentsTheme" },
    { id = "Social",       init = "InitSocialTheme" },
    { id = "Guild",        init = "InitGuildTheme" },
    { id = "Mail",         init = "InitMailTheme" },
    { id = "Auction",      init = "InitAuctionTheme" },
    { id = "Dialogs",      init = "InitDialogsTheme" },
    { id = "Vendors",      init = "InitVendorsTheme" },
    { id = "Tooltips",     init = "InitTooltipsTheme" },
    { id = "Trade",        init = "InitTradeTheme" },
}

function NS.IsModuleEnabled(modId)
    if not ModernCharacterUI_GlobalDB or not ModernCharacterUI_GlobalDB.disabledModules then
        return true
    end
    return not ModernCharacterUI_GlobalDB.disabledModules[modId]
end

SLASH_MODERNUI1 = "/modernui"
SLASH_MODERNUI2 = "/mcui"
SlashCmdList["MODERNUI"] = function(cmd)
    cmd = string.lower(string.trim(cmd or ""))
    if cmd == "version" or cmd == "ver" then
        if NS.versionOutdated then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[ModernUI]|r Tu versión: |cffff5555v%s|r | Última detectada: |cff4ade80v%s|r (¡Desactualizado!).", NS.VERSION, NS.latestVersion))
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[ModernUI]|r Versión actual: |cff4ade80v%s|r (Al día).", NS.VERSION))
        end
    elseif cmd == "modulos" or cmd == "modules" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[ModernUI]|r Módulos disponibles (usa |cffffffff/modernui toggle <nombre>|r):")
        for _, m in ipairs(NS.MODULES_LIST) do
            local status = NS.IsModuleEnabled(m.id) and "|cff4ade80ON|r" or "|cffff5555OFF|r"
            DEFAULT_CHAT_FRAME:AddMessage(" - |cffffffff" .. m.id .. "|r: " .. status)
        end
    elseif string.find(cmd, "^toggle ") then
        local target = string.trim(string.sub(cmd, 8))
        ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
        ModernCharacterUI_GlobalDB.disabledModules = ModernCharacterUI_GlobalDB.disabledModules or {}
        for _, m in ipairs(NS.MODULES_LIST) do
            if string.lower(m.id) == target then
                local newState = not ModernCharacterUI_GlobalDB.disabledModules[m.id]
                ModernCharacterUI_GlobalDB.disabledModules[m.id] = newState or nil
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[ModernUI]|r Módulo |cffffffff%s|r: %s (haz |cffffffff/reload|r para aplicar).", m.id, newState and "|cffff5555Desactivado|r" or "|cff4ade80Activado|r"))
                return
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[ModernUI]|r Módulo no encontrado. Escribe |cffffffff/modernui modulos|r para ver la lista.")
    elseif cmd == "config" or cmd == "opciones" or cmd == "" then
        if NS.ToggleOptionsPanel then NS.ToggleOptionsPanel() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[ModernUI]|r Comandos: |cffffffff/modernui|r | |cffffffff/modernui version|r | |cffffffff/modernui modulos|r")
    end
end

NS.LEFT_PANEL_WIDTH = 265
NS.CENTER_WIDTH = 340
NS.STATS_PANEL_WIDTH = 215
NS.TOTAL_WIDTH = NS.LEFT_PANEL_WIDTH + NS.CENTER_WIDTH + NS.STATS_PANEL_WIDTH

local mainUI = CreateFrame("Frame", "ModernCharacterMainFrame", CharacterFrame)
mainUI:SetFrameLevel(CharacterFrame:GetFrameLevel() - 1)
mainUI:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12, -18)
mainUI:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 12, 74)
mainUI:SetWidth(NS.TOTAL_WIDTH)

NS.ApplyIceBackdrop(mainUI, 0.93, 0.05, 0.14, 0.24, 16, 4)
NS.AddTopGlow(mainUI, 45, 0.35, 4)

NS.mainUI = mainUI

local function SkinBaseFrames()
    local anyCharTabOn = NS.IsModuleEnabled("Character")
        or NS.IsModuleEnabled("Pets")
        or NS.IsModuleEnabled("Reputation")
        or NS.IsModuleEnabled("Skills")
        or NS.IsModuleEnabled("Tokens")

    if not anyCharTabOn then
        mainUI:Hide()
        return
    end

    NS.CleanFrameTextures(CharacterFrame)
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end

    if NS.IsModuleEnabled("Pets") then
        for _, sf in ipairs({ PetPaperDollFrame, PetPaperDollFrameCompanionFrame }) do
            if sf then
                NS.CleanFrameTextures(sf)
                sf:HookScript("OnShow", function() NS.CleanFrameTextures(sf) end)
            end
        end
    end

    if NS.IsModuleEnabled("Skills") and SkillFrame then
        NS.CleanFrameTextures(SkillFrame)
        SkillFrame:HookScript("OnShow", function() NS.CleanFrameTextures(SkillFrame) end)
    end
end

function NS.SetExpandedMode(expanded)
    local isPets   = (CharacterFrame.selectedTab == 2) or (PetPaperDollFrame and PetPaperDollFrame:IsShown())
    local isRep    = (CharacterFrame.selectedTab == 3) or (ReputationFrame and ReputationFrame:IsShown())
    local isSkills = (CharacterFrame.selectedTab == 4) or (SkillFrame and SkillFrame:IsShown())
    local isTokens = (CharacterFrame.selectedTab == 5) or (TokenFrame and TokenFrame:IsShown())

    local charEnabled   = NS.IsModuleEnabled("Character")
    local petsEnabled   = NS.IsModuleEnabled("Pets")
    local repEnabled    = NS.IsModuleEnabled("Reputation")
    local skillsEnabled = NS.IsModuleEnabled("Skills")
    local tokensEnabled = NS.IsModuleEnabled("Tokens")

    local w = 340
    if expanded and charEnabled then
        mainUI:Show()
        w = NS.TOTAL_WIDTH
        if NS.SetCharacterTabVisible then NS.SetCharacterTabVisible(true) end
        if NS.SetSkillsTabVisible then NS.SetSkillsTabVisible(false) end
        if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(false) end
        if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    elseif isSkills and skillsEnabled then
        mainUI:Show()
        w = NS.TOTAL_WIDTH
        if NS.SetCharacterTabVisible then NS.SetCharacterTabVisible(false) end
        if NS.SetSkillsTabVisible then NS.SetSkillsTabVisible(true) end
        if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(false) end
        if CharacterFramePortrait then CharacterFramePortrait:Show() end
    elseif isPets and petsEnabled then
        mainUI:Show()
        w = (NS.GetPetsTabWidth and NS.GetPetsTabWidth()) or 620
        if NS.SetCharacterTabVisible then NS.SetCharacterTabVisible(false) end
        if NS.SetSkillsTabVisible then NS.SetSkillsTabVisible(false) end
        if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(true) end
        if CharacterFramePortrait then CharacterFramePortrait:Show() end
    else
        w = 340
        if NS.SetCharacterTabVisible then NS.SetCharacterTabVisible(false) end
        if NS.SetSkillsTabVisible then NS.SetSkillsTabVisible(false) end
        if NS.SetPetsExtraPanelVisible then NS.SetPetsExtraPanelVisible(false) end
        if CharacterFramePortrait then CharacterFramePortrait:Show() end

        local tabEnabled = (expanded and charEnabled)
            or (isPets and petsEnabled)
            or (isRep and repEnabled)
            or (isSkills and skillsEnabled)
            or (isTokens and tokensEnabled)

        if tabEnabled then
            mainUI:Show()
        else
            mainUI:Hide()
        end
    end

    mainUI:SetWidth(w)
    if CharacterFrameCloseButton then
        CharacterFrameCloseButton:ClearAllPoints()
        CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPLEFT", w + 12, -14)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:RegisterEvent("UNIT_STATS")
loader:RegisterEvent("UNIT_AURA")
loader:RegisterEvent("TRADE_SKILL_SHOW")
loader:RegisterEvent("TRADE_SKILL_UPDATE")
loader:RegisterEvent("CHAT_MSG_ADDON")
loader:RegisterEvent("PARTY_MEMBERS_CHANGED")

loader:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "PLAYER_LOGIN" then
        ModernCharacterUI_RecipesDB = ModernCharacterUI_RecipesDB or {}
        ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
        ModernCharacterUI_GlobalDB.disabledModules = ModernCharacterUI_GlobalDB.disabledModules or {}
        SkinBaseFrames()
        if NS.InitOptionsAndMinimap then NS.InitOptionsAndMinimap() end

        for _, mod in ipairs(NS.MODULES_LIST) do
            if NS.IsModuleEnabled(mod.id) and type(NS[mod.init]) == "function" then
                NS[mod.init]()
            end
        end

        if not NS.IsModuleEnabled("Character") and NS.SetCharacterTabVisible then
            NS.SetCharacterTabVisible(false)
        end
        if not NS.IsModuleEnabled("Skills") and NS.SetSkillsTabVisible then
            NS.SetSkillsTabVisible(false)
        end
        if not NS.IsModuleEnabled("Pets") and NS.SetPetsExtraPanelVisible then
            NS.SetPetsExtraPanelVisible(false)
        end

        for i = 1, 5 do
            local tab = _G["CharacterFrameTab" .. i]
            if tab then
                tab:HookScript("OnClick", function() NS.SetExpandedMode(i == 1) end)
            end
        end

        local secFrames = { PetPaperDollFrame, ReputationFrame, SkillFrame, TokenFrame }
        for _, frame in ipairs(secFrames) do
            if frame then
                frame:HookScript("OnShow", function() NS.SetExpandedMode(false) end)
            end
        end

        if CharacterFrame_ShowSubFrame then
            hooksecurefunc("CharacterFrame_ShowSubFrame", function()
                NS.SetExpandedMode(CharacterFrame.selectedTab == 1)
            end)
        end

        PaperDollFrame:HookScript("OnShow", function() NS.SetExpandedMode(true) end)
        CharacterFrame:HookScript("OnShow", function()
            mainUI:Show()
            NS.SetExpandedMode(PaperDollFrame:IsShown())
            if NS.BroadcastVersion then NS.BroadcastVersion() end
        end)
        CharacterFrame:HookScript("OnHide", function() mainUI:Hide() end)

    elseif event == "PARTY_MEMBERS_CHANGED" then
        if NS.BroadcastVersion then NS.BroadcastVersion() end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        if NS.SaveCurrentTradeSkillRecipes then NS.SaveCurrentTradeSkillRecipes() end
        if mainUI:IsShown() and SkillFrame and SkillFrame:IsShown() and NS.RefreshRecipesList then
            NS.RefreshRecipesList()
        end
    elseif event == "CHAT_MSG_ADDON" then
        if NS.OnSkillsAddonMessage then NS.OnSkillsAddonMessage(arg1, arg2, arg3, arg4) end
    elseif mainUI:IsShown() and PaperDollFrame:IsShown() and NS.IsModuleEnabled("Character")
        and (event == "PLAYER_EQUIPMENT_CHANGED" or arg1 == "player") then
        if NS.RefreshEquipmentList then NS.RefreshEquipmentList() end
        if NS.RefreshAllStats then NS.RefreshAllStats() end
    end
end)
