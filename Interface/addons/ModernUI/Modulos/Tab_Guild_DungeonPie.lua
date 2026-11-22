local addonName, NS = ...

NS.WOTLK_DUNGEON_ACHIEVEMENTS = {
    { 477,  489,  "Fortaleza de Utgarde" },
    { 478,  490,  "El Nexo" },
    { 480,  491,  "Azjol-Nerub" },
    { 481,  492,  "Ahn'kahet: El Antiguo Reino" },
    { 482,  493,  "Fortaleza de Drak'Tharon" },
    { 483,  494,  "El Bastión Violeta" },
    { 484,  495,  "Gundrak" },
    { 485,  496,  "Cámaras de Piedra" },
    { 486,  497,  "Cámaras de Relámpagos" },
    { 487,  498,  "El Oculus" },
    { 488,  499,  "Pináculo de Utgarde" },
    { 479,  500,  "La Matanza de Stratholme" },
    { 4296, 4298, "Prueba del Campeón" },
    { 4516, 4519, "La Forja de Almas" },
    { 4517, 4520, "Foso de Saron" },
    { 4518, 4521, "Cámaras de Reflexión" },
}

NS.guildDungeonCache = NS.guildDungeonCache or {}

local function GetOrCreateDungeonPopup()
    if NS.GuildDungeonPopup then return NS.GuildDungeonPopup end

    local pop = CreateFrame("Frame", "ModernGuildDungeonPopup", UIParent)
    pop:SetSize(250, 325)
    pop:SetFrameStrata("TOOLTIP")
    NS.ApplyIceBackdrop(pop, 0.97, 0.03, 0.10, 0.20, 14, 4)
    NS.AddTopGlow(pop, 28)
    pop:Hide()

    local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", pop, "TOP", 0, -10)
    title:SetText("|cff73d2ffMazmorras de Rasganorte|r")
    pop.title = title

    local sub = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -3)
    pop.sub = sub

    pop.rows = {}
    for i = 1, 16 do
        local row = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", pop, "TOPLEFT", 14, -44 - ((i - 1) * 16))
        row:SetWidth(222)
        row:SetJustifyH("LEFT")
        pop.rows[i] = row
    end

    NS.GuildDungeonPopup = pop
    return pop
end

function NS.GetLocalWotlkDungeonMask()
    if not GetAchievementInfo then return -1, -1 end
    local completed = 0
    local mask = 0
    for idx, entry in ipairs(NS.WOTLK_DUNGEON_ACHIEVEMENTS) do
        local _, _, _, normDone = GetAchievementInfo(entry[1])
        local _, _, _, heroDone = GetAchievementInfo(entry[2])
        if normDone or heroDone then
            completed = completed + 1
            mask = bit.bor(mask, bit.lshift(1, idx - 1))
        end
    end
    return math.floor((completed / 16) * 100), mask
end

function NS.CreateGuildDungeonPie(parent)
    local pie = CreateFrame("Frame", nil, parent)
    pie:SetSize(148, 148)
    pie:EnableMouse(true)

    local bg = pie:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    bg:SetVertexColor(0.03, 0.08, 0.16, 0.92)

    pie.slices = {}
    local radius = 52
    for i = 1, 16 do
        local angle = math.rad(((i - 1) * (360 / 16)) - 90)
        local tex = pie:CreateTexture(nil, "ARTWORK")
        tex:SetSize(22, 22)
        tex:SetPoint("CENTER", pie, "CENTER", math.cos(angle) * radius, -math.sin(angle) * radius)
        tex:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        tex:SetVertexColor(0.85, 0.15, 0.15, 0.90)
        pie.slices[i] = tex
    end

    local centerBg = pie:CreateTexture(nil, "OVERLAY")
    centerBg:SetSize(72, 72)
    centerBg:SetPoint("CENTER", pie, "CENTER", 0, 0)
    centerBg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    centerBg:SetVertexColor(0.04, 0.12, 0.22, 0.98)

    local pctText = pie:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pctText:SetPoint("CENTER", pie, "CENTER", 0, 0)
    pctText:SetText("|cffffffff--%|r")
    pie.pctText = pctText

    pie:SetScript("OnEnter", function(self)
        local pop = GetOrCreateDungeonPopup()
        pop:ClearAllPoints()
        pop:SetPoint("TOPLEFT", self, "TOPRIGHT", 10, 10)

        local pct = self.currentPct
        local mask = self.currentMask

        if pct and pct >= 0 and mask and mask >= 0 then
            local doneCount = 0
            for idx, entry in ipairs(NS.WOTLK_DUNGEON_ACHIEVEMENTS) do
                local isDone = bit.band(mask, bit.lshift(1, idx - 1)) ~= 0
                if isDone then doneCount = doneCount + 1 end
                local _, achName = GetAchievementInfo(entry[1])
                local cleanName = achName and string.gsub(achName, "^.-:%s*", "") or entry[3]
                if isDone then
                    pop.rows[idx]:SetText("|cff22ee44[✔]|r " .. cleanName)
                else
                    pop.rows[idx]:SetText("|cffff4444[✘]|r |cffaaaaaa" .. cleanName .. "|r")
                end
            end
            pop.sub:SetText(string.format("Completadas: |cff4ade80%d/16|r (|cffffffff%d%%|r)", doneCount, pct))
        else
            pop.sub:SetText("|cffffd700Sin datos sincronizados|r")
            for idx, entry in ipairs(NS.WOTLK_DUNGEON_ACHIEVEMENTS) do
                pop.rows[idx]:SetText("|cff666666[?]|r " .. entry[3])
            end
        end
        pop:Show()
    end)

    pie:SetScript("OnLeave", function()
        if NS.GuildDungeonPopup then
            NS.GuildDungeonPopup:Hide()
        end
    end)

    return pie
end

function NS.UpdateGuildDungeonPie(pie, playerName)
    if not pie then return end

    local cleanName = playerName and strsplit("-", playerName) or ""
    local myName = UnitName("player")
    local pct, mask

    if cleanName == myName then
        pct, mask = NS.GetLocalWotlkDungeonMask()
    else
        if IceLFD_DB and IceLFD_DB.dungeonPct and IceLFD_DB.dungeonMask then
            for i = 1, GetNumPartyMembers() do
                local u = "party" .. i
                if UnitExists(u) and UnitName(u) == cleanName then
                    local g = UnitGUID(u)
                    if g and IceLFD_DB.dungeonPct[g] then
                        pct = IceLFD_DB.dungeonPct[g]
                        mask = IceLFD_DB.dungeonMask[g]
                    end
                end
            end
            for i = 1, GetNumRaidMembers() do
                local u = "raid" .. i
                if UnitExists(u) and UnitName(u) == cleanName then
                    local g = UnitGUID(u)
                    if g and IceLFD_DB.dungeonPct[g] then
                        pct = IceLFD_DB.dungeonPct[g]
                        mask = IceLFD_DB.dungeonMask[g]
                    end
                end
            end
        end

        if not pct and NS.guildDungeonCache[cleanName] then
            pct = NS.guildDungeonCache[cleanName].pct
            mask = NS.guildDungeonCache[cleanName].mask
        end
    end

    pie.currentPct = pct
    pie.currentMask = mask

    if pct and pct >= 0 and mask and mask >= 0 then
        pie.pctText:SetText(string.format("|cffffffff%d%%|r", pct))
        for i = 1, 16 do
            local isDone = bit.band(mask, bit.lshift(1, i - 1)) ~= 0
            if isDone then
                pie.slices[i]:SetVertexColor(0.15, 0.88, 0.25, 1.0)
            else
                pie.slices[i]:SetVertexColor(0.88, 0.16, 0.16, 0.95)
            end
        end
    else
        pie.pctText:SetText("|cff888888--%|r")
        for i = 1, 16 do
            pie.slices[i]:SetVertexColor(0.25, 0.32, 0.42, 0.65)
        end
    end
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")
syncFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

local lastGuildBroadcast = 0
local function BroadcastMyGuildDungeons()
    if not IsInGuild() or (GetTime() - lastGuildBroadcast < 30) then return end
    local pct, mask = NS.GetLocalWotlkDungeonMask()
    if pct >= 0 then
        lastGuildBroadcast = GetTime()
        SendAddonMessage("DBM", string.format("MUI_GD;%s;%d;%d", UnitName("player"), pct, mask), "GUILD")
    end
end

syncFrame:SetScript("OnEvent", function(_, event, prefix, msg)
    if event == "GUILD_ROSTER_UPDATE" then
        BroadcastMyGuildDungeons()
    elseif event == "CHAT_MSG_ADDON" and prefix == "DBM" and msg and string.find(msg, "^MUI_GD;") then
        local _, pName, pctStr, maskStr = strsplit(";", msg)
        local p, m = tonumber(pctStr), tonumber(maskStr)
        if pName and p and m then
            NS.guildDungeonCache[pName] = { pct = p, mask = m }
            if GuildMemberDetailFrame and GuildMemberDetailFrame:IsShown() and NS.UpdateGuildMemberDetailText then
                NS.UpdateGuildMemberDetailText()
            end
        end
    end
end)
