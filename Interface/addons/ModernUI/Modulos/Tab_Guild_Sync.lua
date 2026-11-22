local addonName, NS = ...

local PREFIX = "DBM"
local TAG = "MUI_GSYNC"
local SEND_INTERVAL = 1.2
local MAX_QUEUE = 25
local REQ_COOLDOWN = 20

local msgQueue = {}
local lastSendTime = 0
local lastFullShareTime = 0
local lastReqTime = 0
local loginSyncDelay = nil

function NS.InitGuildSyncCache()
    if type(ModernUI_GuildCache) ~= "table" then
        ModernUI_GuildCache = {}
    end
    NS.guildDungeonCache = NS.guildDungeonCache or {}
    NS.guildRaidCache = NS.guildRaidCache or {}

    for pName, data in pairs(ModernUI_GuildCache) do
        if type(data) == "table" then
            if data.dPct and data.dMask then
                NS.guildDungeonCache[pName] = { pct = data.dPct, mask = data.dMask }
            end
            if data.rPct and data.rMask then
                NS.guildRaidCache[pName] = { pct = data.rPct, mask = data.rMask }
            end
        end
    end
end

local function SaveMemberToCache(pName, dPct, dMask, rPct, rMask)
    if not pName or pName == "" then return false end
    NS.InitGuildSyncCache()

    local entry = ModernUI_GuildCache[pName] or {}
    local changed = false

    if dPct and dPct >= 0 and dMask and dMask >= 0 then
        if entry.dPct ~= dPct or entry.dMask ~= dMask then
            entry.dPct = dPct
            entry.dMask = dMask
            NS.guildDungeonCache[pName] = { pct = dPct, mask = dMask }
            changed = true
        end
    end

    if rPct and rPct >= 0 and rMask and rMask >= 0 then
        if entry.rPct ~= rPct or entry.rMask ~= rMask then
            entry.rPct = rPct
            entry.rMask = rMask
            NS.guildRaidCache[pName] = { pct = rPct, mask = rMask }
            changed = true
        end
    end

    if changed then
        entry.ts = time()
        ModernUI_GuildCache[pName] = entry
    end
    return changed
end

local function EnqueueGuildMsg(payload)
    if not IsInGuild() or #msgQueue >= MAX_QUEUE then return end
    for _, queued in ipairs(msgQueue) do
        if queued == payload then return end
    end
    table.insert(msgQueue, payload)
end

-- Captura los datos del jugador local y los guarda en caché
function NS.UpdateLocalGuildCache()
    local myName = UnitName("player")
    if not myName then return end

    local dPct, dMask = -1, -1
    local rPct, rMask = -1, -1

    if NS.GetLocalWotlkDungeonMask then
        dPct, dMask = NS.GetLocalWotlkDungeonMask()
    end
    if NS.GetLocalWotlkRaidMask then
        rPct, rMask = NS.GetLocalWotlkRaidMask()
    end

    SaveMemberToCache(myName, dPct, dMask, rPct, rMask)
end

-- Envía toda la caché conocida al canal GUILD respetando el anti-flood
function NS.ShareGuildCache(force)
    if not IsInGuild() then return end
    local now = GetTime()
    if not force and (now - lastFullShareTime < REQ_COOLDOWN) then return end
    lastFullShareTime = now

    NS.UpdateLocalGuildCache()

    -- Construye un mapa de miembros actuales de la hermandad para no enviar datos obsoletos
    local validMembers = {}
    local total = GetNumGuildMembers() or 0
    for i = 1, total do
        local fullName = GetGuildRosterInfo(i)
        if fullName then
            local clean = strsplit("-", fullName)
            validMembers[clean] = true
        end
    end

    -- Primero encola siempre los datos propios
    local myName = UnitName("player")
    local myData = ModernUI_GuildCache[myName]
    if myData then
        EnqueueGuildMsg(string.format("%s;D;%s;%d;%d;%d;%d",
            TAG, myName, myData.dPct or -1, myData.dMask or -1, myData.rPct or -1, myData.rMask or -1))
    end

    -- Luego encola el resto de miembros en caché (máximo hasta llenar MAX_QUEUE)
    for pName, data in pairs(ModernUI_GuildCache) do
        if pName ~= myName and (total == 0 or validMembers[pName]) then
            EnqueueGuildMsg(string.format("%s;D;%s;%d;%d;%d;%d",
                TAG, pName, data.dPct or -1, data.dMask or -1, data.rPct or -1, data.rMask or -1))
        end
    end
end

function NS.RequestGuildCache()
    if not IsInGuild() then return end
    local now = GetTime()
    if now - lastReqTime < REQ_COOLDOWN then return end
    lastReqTime = now
    EnqueueGuildMsg(TAG .. ";REQ")
end

local syncDriver = CreateFrame("Frame")
syncDriver:RegisterEvent("ADDON_LOADED")
syncDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
syncDriver:RegisterEvent("GUILD_ROSTER_UPDATE")
syncDriver:RegisterEvent("ACHIEVEMENT_EARNED")
syncDriver:RegisterEvent("CHAT_MSG_ADDON")

syncDriver:SetScript("OnUpdate", function(_, elapsed)
    -- Retraso aleatorio inicial al entrar al juego (entre 4 y 8 segundos) para evitar picos
    if loginSyncDelay then
        loginSyncDelay = loginSyncDelay - elapsed
        if loginSyncDelay <= 0 then
            loginSyncDelay = nil
            NS.UpdateLocalGuildCache()
            NS.RequestGuildCache()
            NS.ShareGuildCache(false)
        end
    end

    -- Vaciado pausado de la cola anti-flood (1 mensaje cada 1.2s)
    if #msgQueue > 0 and (GetTime() - lastSendTime >= SEND_INTERVAL) then
        lastSendTime = GetTime()
        local pkt = table.remove(msgQueue, 1)
        if IsInGuild() then
            SendAddonMessage(PREFIX, pkt, "GUILD")
        end
    end
end)

syncDriver:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == addonName then
        NS.InitGuildSyncCache()
        NS.UpdateLocalGuildCache()
    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.InitGuildSyncCache()
        -- Jitter aleatorio para que no todos pidan datos en el mismo segundo
        loginSyncDelay = 4 + (math.random(0, 40) / 10)
    elseif event == "ACHIEVEMENT_EARNED" then
        NS.UpdateLocalGuildCache()
        NS.ShareGuildCache(false)
    elseif event == "GUILD_ROSTER_UPDATE" then
        NS.UpdateLocalGuildCache()
    elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX and arg2 and string.find(arg2, "^" .. TAG .. ";") then
        local cleanSender = arg4 and strsplit("-", arg4) or ""
        if cleanSender == UnitName("player") then return end

        local _, cmd, pName, dPctStr, dMaskStr, rPctStr, rMaskStr = strsplit(";", arg2)
        if cmd == "REQ" then
            -- Retraso aleatorio de respuesta (1 a 4s) para evitar colisión de respuestas en hermandad
            if not loginSyncDelay then
                loginSyncDelay = 1 + (math.random(0, 30) / 10)
            end
        elseif cmd == "D" then
            local updated = SaveMemberToCache(
                pName,
                tonumber(dPctStr),
                tonumber(dMaskStr),
                tonumber(rPctStr),
                tonumber(rMaskStr)
            )
            if updated and GuildMemberDetailFrame and GuildMemberDetailFrame:IsShown() and NS.UpdateGuildMemberDetailText then
                NS.UpdateGuildMemberDetailText()
            end
        end
    end
end)
