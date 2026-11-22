local addonName, addon = ...
local EventFrame = CreateFrame("Frame")

local PRIVATE_CHANNEL_NAME = "IceLFD_Sync"
local privateChannelId = nil
local channelJoinTimer = 0
local channelJoined = false

local currentInspectUnit = nil
local lastInspectTime = 0
local inspectWaitTimer = 0

local msgQueue = {}
local MAX_QUEUE_SIZE = 20
local lastSendTime = 0
local lastReqTime = 0
local lastShareTime = 0
local lastVerBroadcast = 0
local initVerTimer = 0
local initVerSent = false

local lastSentPayload = {}
local lastSentTimestamp = {}

local function EnsurePrivateChannel()
    local id = GetChannelName(PRIVATE_CHANNEL_NAME)
    if id and id > 0 then
        privateChannelId = id
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf then
                ChatFrame_RemoveChannel(cf, PRIVATE_CHANNEL_NAME)
            end
        end
        return id
    end
    return nil
end

local function QueueAddonMessage(msg, targetChannel)
    if #msgQueue >= MAX_QUEUE_SIZE then return end
    for _, queued in ipairs(msgQueue) do
        if queued.msg == msg and queued.target == targetChannel then return end
    end
    table.insert(msgQueue, { msg = msg, target = targetChannel })
end

function addon.CaptureUnitMeta(unit, guid)
    if not guid then return nil end
    local _, raceEn = UnitRace(unit)
    local sex = UnitSex(unit)
    if raceEn and (sex == 2 or sex == 3) then
        local meta = raceEn .. "," .. sex
        addon.metaCache[guid] = meta
        return meta
    end
    return addon.metaCache[guid]
end

function addon.ScanUnitData(unit)
    local totalIlvl = 0
    local itemCount = 0
    local missingData = false
    local itemIds = {}

    for slot = 1, 19 do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local itemId = string.match(link, "item:(%d+)")
            if itemId then
                for _, vSlot in ipairs(addon.VISIBLE_SLOTS) do
                    if vSlot == slot then
                        table.insert(itemIds, itemId)
                        break
                    end
                end
            end

            if slot ~= 4 and slot ~= 19 then
                local _, _, _, itemLevel = GetItemInfo(link)
                if itemLevel and itemLevel > 0 then
                    totalIlvl = totalIlvl + itemLevel
                    itemCount = itemCount + 1
                else
                    missingData = true
                end
            end
        end
    end

    if missingData then return -1, nil end

    local avgIlvl = (itemCount > 0) and math.floor(totalIlvl / itemCount) or 0
    return avgIlvl, table.concat(itemIds, ",")
end

function addon.GetLocalRolesStr()
    local r = ""
    if LFDQueueFrameRoleButtonTank and LFDQueueFrameRoleButtonTank.checkButton:GetChecked() then r = r .. "T" end
    if LFDQueueFrameRoleButtonHealer and LFDQueueFrameRoleButtonHealer.checkButton:GetChecked() then r = r .. "H" end
    if LFDQueueFrameRoleButtonDPS and LFDQueueFrameRoleButtonDPS.checkButton:GetChecked() then r = r .. "D" end
    return r
end

function addon.GetUnspentTalents(unit, isInspect)
    local level = UnitLevel(unit)
    if not level or level < 10 then return 0 end

    local expected = level - 9
    local spent = 0
    for tab = 1, 3 do
        local _, _, pointsSpent = GetTalentTabInfo(tab, isInspect)
        spent = spent + (pointsSpent or 0)
    end

    local unspent = expected - spent
    return (unspent > 0) and unspent or 0
end

-- IDs oficiales de Logros (Normal y Heroico) de las 16 mazmorras de WotLK en 3.3.5a
addon.WOTLK_DUNGEON_ACHIEVEMENTS = {
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

function addon.GetLocalDungeonProgress()
    if not GetAchievementInfo then return -1, -1 end
    local completed = 0
    local mask = 0
    local total = #addon.WOTLK_DUNGEON_ACHIEVEMENTS

    for idx, entry in ipairs(addon.WOTLK_DUNGEON_ACHIEVEMENTS) do
        local normalId, heroicId = entry[1], entry[2]
        local _, _, _, normDone = GetAchievementInfo(normalId)
        local _, _, _, heroDone = GetAchievementInfo(heroicId)
        if normDone or heroDone then
            completed = completed + 1
            mask = bit.bor(mask, bit.lshift(1, idx - 1))
        end
    end

    return math.floor((completed / total) * 100), mask
end

function addon.CheckRemoteVersion(remoteVer, sender)
    if not remoteVer or remoteVer == "" then return false end
    local cmp = addon.CompareVersions and addon.CompareVersions(remoteVer, addon.latestVersion) or 0
    if cmp == 1 then
        addon.latestVersion = remoteVer
        addon.versionOutdated = true
        if not addon.versionNotified then
            addon.versionNotified = true
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[IceLFD]|r ¡Hay una nueva versión disponible! (|cff4ade80v%s|r - Tú tienes |cffff5555v%s|r).", remoteVer, addon.VERSION))
        end
        if LFDParentFrame and LFDParentFrame:IsShown() then
            addon.UpdatePartyDisplay()
        end
    end
    return addon.CompareVersions and addon.CompareVersions(addon.VERSION, remoteVer) == 1
end

function addon.BroadcastVersion(force)
    if not addon.VERSION then return end
    if not force and (GetTime() - lastVerBroadcast < 20) then return end
    lastVerBroadcast = GetTime()

    local verPacket = string.format("%s;VER;%s", addon.TAG, addon.VERSION)
    if IsInGuild() then
        QueueAddonMessage(verPacket, "GUILD")
    end
    if GetNumRaidMembers() > 0 then
        QueueAddonMessage(verPacket, "RAID")
    elseif GetNumPartyMembers() > 0 then
        QueueAddonMessage(verPacket, "PARTY")
    end
    if EnsurePrivateChannel() then
        QueueAddonMessage(verPacket, "CHANNEL")
    end
end

function addon.BroadcastUnitData(guid, ilvl, gearStr, metaStr, rolesStr, unspentTalents, dungeonPct, dungeonMask)
    if not guid or not ilvl or ilvl <= 0 then return end
    local rStr = rolesStr or (addon.roleCache and addon.roleCache[guid]) or ""
    local tVal = unspentTalents or (addon.talentCache and addon.talentCache[guid]) or 0
    local dPct = dungeonPct or (addon.dungeonPctCache and addon.dungeonPctCache[guid]) or -1
    local dMask = dungeonMask or (addon.dungeonMaskCache and addon.dungeonMaskCache[guid]) or -1
    local packet = string.format("%s;D;%s;%d;%s;%s;%s;%d;%d;%d", addon.TAG, guid, ilvl, metaStr or "", gearStr or "", rStr, tVal, dPct, dMask)

    local now = GetTime()
    if lastSentPayload[guid] == packet and (now - (lastSentTimestamp[guid] or 0)) < 15 then
        return
    end
    lastSentPayload[guid] = packet
    lastSentTimestamp[guid] = now

    if GetNumPartyMembers() > 0 then
        QueueAddonMessage(packet, "PARTY")
    end
    if EnsurePrivateChannel() then
        QueueAddonMessage(packet, "CHANNEL")
    end
end

function addon.ShareAllKnownData()
    if GetTime() - lastShareTime < 5 then return end
    lastShareTime = GetTime()

    local myGuid = UnitGUID("player")
    local myMeta = addon.CaptureUnitMeta("player", myGuid)
    local myIlvl, myGear = addon.ScanUnitData("player")
    if myGuid then
        addon.roleCache[myGuid] = addon.GetLocalRolesStr()
        addon.talentCache[myGuid] = addon.GetUnspentTalents("player", false)
        local pct, mask = addon.GetLocalDungeonProgress()
        if pct >= 0 then
            addon.dungeonPctCache[myGuid] = pct
            addon.dungeonMaskCache[myGuid] = mask
        end
        if myIlvl > 0 then
            addon.ilvlCache[myGuid] = myIlvl
            if myGear then addon.gearCache[myGuid] = myGear end
        end
    end

    if myGuid and addon.ilvlCache[myGuid] then
        addon.BroadcastUnitData(myGuid, addon.ilvlCache[myGuid], addon.gearCache[myGuid], addon.metaCache[myGuid], addon.roleCache[myGuid], addon.talentCache[myGuid], addon.dungeonPctCache[myGuid], addon.dungeonMaskCache[myGuid])
    end

    for i = 1, GetNumPartyMembers() do
        local pGuid = UnitGUID("party" .. i)
        if pGuid and addon.ilvlCache[pGuid] then
            addon.BroadcastUnitData(pGuid, addon.ilvlCache[pGuid], addon.gearCache[pGuid], addon.metaCache[pGuid], addon.roleCache[pGuid], addon.talentCache[pGuid], addon.dungeonPctCache[pGuid], addon.dungeonMaskCache[pGuid])
        end
    end

    addon.BroadcastVersion()
end

local function RequestGroupData()
    if GetTime() - lastReqTime < 8 then return end
    lastReqTime = GetTime()
    local reqPacket = addon.TAG .. ";REQ"
    if GetNumPartyMembers() > 0 then
        QueueAddonMessage(reqPacket, "PARTY")
    elseif EnsurePrivateChannel() then
        QueueAddonMessage(reqPacket, "CHANNEL")
    end
end

local function ProcessInspectResult()
    if currentInspectUnit and UnitExists(currentInspectUnit) then
        local guid = UnitGUID(currentInspectUnit)
        local meta = addon.CaptureUnitMeta(currentInspectUnit, guid)
        local ilvl, gearStr = addon.ScanUnitData(currentInspectUnit)

        if ilvl > 0 and guid then
            addon.ilvlCache[guid] = ilvl
            addon.talentCache[guid] = addon.GetUnspentTalents(currentInspectUnit, true)
            if gearStr then addon.gearCache[guid] = gearStr end
            addon.BroadcastUnitData(guid, ilvl, gearStr, meta, addon.roleCache[guid], addon.talentCache[guid], addon.dungeonPctCache[guid], addon.dungeonMaskCache[guid])
            ClearInspectPlayer()
            currentInspectUnit = nil
            addon.UpdatePartyDisplay()
        elseif ilvl == -1 then
            addon.inspectQueue[currentInspectUnit] = true
            currentInspectUnit = nil
        end
    end
end

local function HandleIncomingPacket(msg, sender)
    if not msg or not string.find(msg, "^" .. addon.TAG .. ";") then return end

    addon.DebugPrint("Recibido de " .. tostring(sender) .. ": " .. msg)
    local _, cmd, guid, ilvlStr, metaStr, gearStr, rolesStr, unspentStr, pctStr, maskStr = strsplit(";", msg)
    if cmd == "REQ" then
        addon.ShareAllKnownData()
    elseif cmd == "VER" then
        local cleanSender = sender and strsplit("-", sender) or ""
        if cleanSender ~= UnitName("player") then
            local iAmNewer = addon.CheckRemoteVersion(guid, sender)
            if iAmNewer then
                addon.BroadcastVersion(true)
            end
        end
    elseif cmd == "D" then
        local ilvl = tonumber(ilvlStr)
        if guid and ilvl and ilvl > 0 then
            local updated = false
            if addon.ilvlCache[guid] ~= ilvl then
                addon.ilvlCache[guid] = ilvl
                updated = true
            end
            if metaStr and metaStr ~= "" and addon.metaCache[guid] ~= metaStr then
                addon.metaCache[guid] = metaStr
                updated = true
            end
            if gearStr and gearStr ~= "" and addon.gearCache[guid] ~= gearStr then
                addon.gearCache[guid] = gearStr
                addon.PreloadItems(gearStr)
                updated = true
            end
            if rolesStr and rolesStr ~= "" and addon.roleCache[guid] ~= rolesStr then
                addon.roleCache[guid] = rolesStr
                updated = true
            end
            local unspent = tonumber(unspentStr)
            if unspent and addon.talentCache[guid] ~= unspent then
                addon.talentCache[guid] = unspent
                updated = true
            end
            local dPct = tonumber(pctStr)
            if dPct and dPct >= 0 and addon.dungeonPctCache[guid] ~= dPct then
                addon.dungeonPctCache[guid] = dPct
                updated = true
            end
            local dMask = tonumber(maskStr)
            if dMask and dMask >= 0 and addon.dungeonMaskCache[guid] ~= dMask then
                addon.dungeonMaskCache[guid] = dMask
                updated = true
            end
            if updated and LFDParentFrame and LFDParentFrame:IsShown() then
                addon.UpdatePartyDisplay()
            end
        end
    end
end

EventFrame:SetScript("OnUpdate", function(self, elapsed)
    if not initVerSent then
        initVerTimer = initVerTimer + elapsed
        if initVerTimer >= 5 then
            initVerSent = true
            addon.BroadcastVersion(true)
        end
    end

    if not channelJoined then
        channelJoinTimer = channelJoinTimer + elapsed
        if channelJoinTimer >= 4 then
            channelJoined = true
            JoinTemporaryChannel(PRIVATE_CHANNEL_NAME)
            EnsurePrivateChannel()
        end
    end

    if #msgQueue > 0 and (GetTime() - lastSendTime >= 0.5) then
        local item = table.remove(msgQueue, 1)
        lastSendTime = GetTime()
        if item.target == "GUILD" and IsInGuild() then
            SendAddonMessage(addon.PREFIX, item.msg, "GUILD")
            addon.DebugPrint("Enviado [GUILD]: " .. item.msg)
        elseif item.target == "RAID" and GetNumRaidMembers() > 0 then
            SendAddonMessage(addon.PREFIX, item.msg, "RAID")
            addon.DebugPrint("Enviado [RAID]: " .. item.msg)
        elseif item.target == "PARTY" and GetNumPartyMembers() > 0 then
            SendAddonMessage(addon.PREFIX, item.msg, "PARTY")
            addon.DebugPrint("Enviado [PARTY]: " .. item.msg)
        elseif item.target == "CHANNEL" then
            local chId = EnsurePrivateChannel()
            if chId then
                SendChatMessage(item.msg, "CHANNEL", nil, chId)
                addon.DebugPrint("Enviado [CANAL]: " .. item.msg)
            end
        end
    end

    if not addon.PartySideFrame:IsShown() then return end

    if currentInspectUnit then
        inspectWaitTimer = inspectWaitTimer + elapsed
        if inspectWaitTimer >= 0.5 then
            inspectWaitTimer = 0
            ProcessInspectResult()
        end
    end

    if GetTime() - lastInspectTime > 1.5 then
        for unit, _ in pairs(addon.inspectQueue) do
            if UnitExists(unit) and CheckInteractDistance(unit, 1) and CanInspect(unit) then
                if not InspectFrame or not InspectFrame:IsShown() then
                    currentInspectUnit = unit
                    inspectWaitTimer = 0
                    lastInspectTime = GetTime()
                    NotifyInspect(unit)
                    addon.inspectQueue[unit] = nil
                    break
                end
            else
                addon.inspectQueue[unit] = nil
            end
        end
    end
end)

EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("CHANNEL_UI_UPDATE")
EventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
EventFrame:RegisterEvent("UNIT_CONNECTION")
EventFrame:RegisterEvent("UNIT_MODEL_CHANGED")
EventFrame:RegisterEvent("INSPECT_TALENT_READY")
EventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
EventFrame:RegisterEvent("CHAT_MSG_ADDON")
EventFrame:RegisterEvent("LFG_ROLE_UPDATE")

EventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon.InitDB()
        if LFDParentFrame then
            LFDParentFrame:HookScript("OnShow", function()
                addon.ApplyIceBlueTheme()
                addon.ShareAllKnownData()
                addon.UpdatePartyDisplay()
                RequestGroupData()
            end)
        end
        if LFDQueueFrame then
            LFDQueueFrame:HookScript("OnShow", function()
                addon.ApplyIceBlueTheme()
            end)
            for _, btnName in ipairs({ "LFDQueueFrameRoleButtonTank", "LFDQueueFrameRoleButtonHealer", "LFDQueueFrameRoleButtonDPS" }) do
                local btn = _G[btnName]
                if btn and btn.checkButton then
                    btn.checkButton:HookScript("OnClick", function()
                        addon.UpdatePartyDisplay()
                        addon.ShareAllKnownData()
                    end)
                end
            end
            if LFDQueueFrame_SetType then
                hooksecurefunc("LFDQueueFrame_SetType", function()
                    addon.UpdatePartyDisplay()
                end)
            end
            if LFDQueueFrameSpecificList_Update then
                hooksecurefunc("LFDQueueFrameSpecificList_Update", function()
                    if LFDParentFrame and LFDParentFrame:IsShown() then
                        addon.UpdatePartyDisplay()
                    end
                end)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "CHANNEL_UI_UPDATE" then
        EnsurePrivateChannel()
    elseif event == "CHAT_MSG_CHANNEL" and arg9 == PRIVATE_CHANNEL_NAME then
        HandleIncomingPacket(arg1, arg2)
    elseif event == "PARTY_MEMBERS_CHANGED" then
        addon.ShareAllKnownData()
        RequestGroupData()
        if LFDParentFrame and LFDParentFrame:IsShown() then
            addon.UpdatePartyDisplay()
        end
    elseif event == "UNIT_MODEL_CHANGED" or event == "LFG_ROLE_UPDATE" or event == "UNIT_CONNECTION" then
        if LFDParentFrame and LFDParentFrame:IsShown() then
            addon.UpdatePartyDisplay()
        end
    elseif event == "INSPECT_TALENT_READY" then
        ProcessInspectResult()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            local myGuid = UnitGUID("player")
            local myMeta = addon.CaptureUnitMeta("player", myGuid)
            local myIlvl, myGear = addon.ScanUnitData("player")
            if myGuid then
                addon.roleCache[myGuid] = addon.GetLocalRolesStr()
                addon.talentCache[myGuid] = addon.GetUnspentTalents("player", false)
                local pct, mask = addon.GetLocalDungeonProgress()
                if pct >= 0 then
                    addon.dungeonPctCache[myGuid] = pct
                    addon.dungeonMaskCache[myGuid] = mask
                end
                if myIlvl > 0 then
                    addon.ilvlCache[myGuid] = myIlvl
                    if myGear then addon.gearCache[myGuid] = myGear end
                    addon.BroadcastUnitData(myGuid, myIlvl, myGear, myMeta, addon.roleCache[myGuid], addon.talentCache[myGuid], addon.dungeonPctCache[myGuid], addon.dungeonMaskCache[myGuid])
                end
            end
        elseif arg1 and string.find(arg1, "party") then
            local guid = UnitGUID(arg1)
            if guid then
                addon.ilvlCache[guid] = nil
                addon.gearCache[guid] = nil
            end
            if LFDParentFrame and LFDParentFrame:IsShown() then
                addon.UpdatePartyDisplay()
            end
        end
    elseif event == "CHAT_MSG_ADDON" and arg1 == addon.PREFIX then
        HandleIncomingPacket(arg2, arg4)
    end
end)
