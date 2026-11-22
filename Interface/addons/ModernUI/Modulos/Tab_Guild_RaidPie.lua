local addonName, NS = ...

-- Logros oficiales de las 9 Bandas (10j y 25j) de Wrath of the Lich King en 3.3.5a
NS.WOTLK_RAID_ACHIEVEMENTS = {
    { 576,  577,  "Naxxramas" },
    { 1876, 625,  "El Sagrario Obsidiana" },
    { 622,  623,  "El Ojo de la Eternidad" },
    { 1722, 1721, "La Cámara de Archavon" },
    { 2894, 2895, "Ulduar" },
    { 3917, 3916, "Prueba del Cruzado" },
    { 4396, 4397, "La Guarida de Onyxia" },
    { 4532, 4608, "Ciudadela de la Corona de Hielo" },
    { 4817, 4815, "El Sagrario Rubí" },
}

NS.guildRaidCache = NS.guildRaidCache or {}

local function GetOrCreateRaidPopup()
    if NS.GuildRaidPopup then return NS.GuildRaidPopup end

    local pop = CreateFrame("Frame", "ModernGuildRaidPopup", UIParent)
    pop:SetSize(270, 225)
    pop:SetFrameStrata("TOOLTIP")
    NS.ApplyIceBackdrop(pop, 0.97, 0.03, 0.10, 0.20, 14, 4)
    NS.AddTopGlow(pop, 28)
    pop:Hide()

    local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", pop, "TOP", 0, -10)
    title:SetText("|cff73d2ffBandas de Rasganorte (10 / 25)|r")
    pop.title = title

    local sub = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -3)
    pop.sub = sub

    pop.rows = {}
    for i = 1, 9 do
        local row = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", pop, "TOPLEFT", 14, -46 - ((i - 1) * 18))
        row:SetWidth(242)
        row:SetJustifyH("LEFT")
        pop.rows[i] = row
    end

    NS.GuildRaidPopup = pop
    return pop
end

function NS.GetLocalWotlkRaidMask()
    if not GetAchievementInfo then return -1, -1 end
    local completed = 0
    local mask = 0
    for idx, entry in ipairs(NS.WOTLK_RAID_ACHIEVEMENTS) do
        local _, _, _, done10 = GetAchievementInfo(entry[1])
        local _, _, _, done25 = GetAchievementInfo(entry[2])
        if done10 then
            completed = completed + 1
            mask = bit.bor(mask, bit.lshift(1, (idx - 1) * 2))
        end
        if done25 then
            completed = completed + 1
            mask = bit.bor(mask, bit.lshift(1, ((idx - 1) * 2) + 1))
        end
    end
    return math.floor((completed / 18) * 100), mask
end

function NS.CreateGuildRaidPie(parent)
    local pie = CreateFrame("Frame", nil, parent)
    pie:SetSize(148, 148)
    pie:EnableMouse(true)

    local bg = pie:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    bg:SetVertexColor(0.03, 0.08, 0.16, 0.92)

    -- 18 porciones del quesito (9 bandas x 2 modalidades: 10j y 25j)
    pie.slices = {}
    local radius = 52
    for i = 1, 18 do
        local angle = math.rad(((i - 1) * (360 / 18)) - 90)
        local tex = pie:CreateTexture(nil, "ARTWORK")
        tex:SetSize(20, 20)
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
    pctText:SetPoint("CENTER", pie, "CENTER", 0, 4)
    pctText:SetText("|cffffffff--%|r")
    pie.pctText = pctText

    local subLabel = pie:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subLabel:SetPoint("TOP", pctText, "BOTTOM", 0, -1)
    subLabel:SetText("|cff73d2ffRaids|r")

    pie:SetScript("OnEnter", function(self)
        local pop = GetOrCreateRaidPopup()
        pop:ClearAllPoints()
        pop:SetPoint("TOPLEFT", self, "TOPRIGHT", 10, 10)

        local pct = self.currentPct
        local mask = self.currentMask

        if pct and pct >= 0 and mask and mask >= 0 then
            local doneCount = 0
            for idx, entry in ipairs(NS.WOTLK_RAID_ACHIEVEMENTS) do
                local d10 = bit.band(mask, bit.lshift(1, (idx - 1) * 2)) ~= 0
                local d25 = bit.band(mask, bit.lshift(1, ((idx - 1) * 2) + 1)) ~= 0
                if d10 then doneCount = doneCount + 1 end
                if d25 then doneCount = doneCount + 1 end

                local tag10 = d10 and "|cff22ee44[10✔]|r" or "|cffff4444[10✘]|r"
                local tag25 = d25 and "|cff22ee44[25✔]|r" or "|cffff4444[25✘]|r"
                pop.rows[idx]:SetText(string.format("%s %s  %s", tag10, tag25, entry[3]))
            end
            pop.sub:SetText(string.format("Modalidades completadas: |cff4ade80%d/18|r (|cffffffff%d%%|r)", doneCount, pct))
        else
            pop.sub:SetText("|cffffd700Sin datos sincronizados|r")
            for idx, entry in ipairs(NS.WOTLK_RAID_ACHIEVEMENTS) do
                pop.rows[idx]:SetText("|cff666666[10?] [25?]|r  " .. entry[3])
            end
        end
        pop:Show()
    end)

    pie:SetScript("OnLeave", function()
        if NS.GuildRaidPopup then
            NS.GuildRaidPopup:Hide()
        end
    end)

    return pie
end

function NS.UpdateGuildRaidPie(pie, playerName)
    if not pie then return end

    local cleanName = playerName and strsplit("-", playerName) or ""
    local myName = UnitName("player")
    local pct, mask

    if cleanName == myName then
        pct, mask = NS.GetLocalWotlkRaidMask()
    elseif NS.guildRaidCache[cleanName] then
        pct = NS.guildRaidCache[cleanName].pct
        mask = NS.guildRaidCache[cleanName].mask
    end

    pie.currentPct = pct
    pie.currentMask = mask

    if pct and pct >= 0 and mask and mask >= 0 then
        pie.pctText:SetText(string.format("|cffffffff%d%%|r", pct))
        for i = 1, 18 do
            local isDone = bit.band(mask, bit.lshift(1, i - 1)) ~= 0
            if isDone then
                pie.slices[i]:SetVertexColor(0.15, 0.88, 0.25, 1.0)
            else
                pie.slices[i]:SetVertexColor(0.88, 0.16, 0.16, 0.95)
            end
        end
    else
        pie.pctText:SetText("|cff888888--%|r")
        for i = 1, 18 do
            pie.slices[i]:SetVertexColor(0.25, 0.32, 0.42, 0.65)
        end
    end
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")
syncFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

local lastRaidBroadcast = 0
local function BroadcastMyGuildRaids()
    if not IsInGuild() or (GetTime() - lastRaidBroadcast < 30) then return end
    local pct, mask = NS.GetLocalWotlkRaidMask()
    if pct >= 0 then
        lastRaidBroadcast = GetTime()
        SendAddonMessage("DBM", string.format("MUI_GR;%s;%d;%d", UnitName("player"), pct, mask), "GUILD")
    end
end

syncFrame:SetScript("OnEvent", function(_, event, prefix, msg)
    if event == "GUILD_ROSTER_UPDATE" then
        BroadcastMyGuildRaids()
    elseif event == "CHAT_MSG_ADDON" and prefix == "DBM" and msg and string.find(msg, "^MUI_GR;") then
        local _, pName, pctStr, maskStr = strsplit(";", msg)
        local p, m = tonumber(pctStr), tonumber(maskStr)
        if pName and p and m then
            NS.guildRaidCache[pName] = { pct = p, mask = m }
            if GuildMemberDetailFrame and GuildMemberDetailFrame:IsShown() and NS.UpdateGuildMemberDetailText then
                NS.UpdateGuildMemberDetailText()
            end
        end
    end
end)
