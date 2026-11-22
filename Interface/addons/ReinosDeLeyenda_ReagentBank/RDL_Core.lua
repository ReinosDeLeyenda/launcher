RDL_BankCache = RDL_BankCache or {}
RDL_ReagentBankCache = RDL_ReagentBankCache or {}
RDL_Core = {}

RDL_Core.VERSION = "3.6.1"
local ADDON_PREFIX = "RDL_PROF_VER"
local updateNotified = false
local highestSeenVersion = RDL_Core.VERSION

local bankOpen, guildBankOpen = false, false
local qSpell, qName, qRem = nil, nil, 0
local lastCraftedGearID, pendingBankStoreID = nil, nil
local timerFrame = CreateFrame("Frame")
local countCache = {}
local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }

function RDL_Core.IsEquippableGear(linkOrID)
    if not linkOrID then return false end
    local _, _, _, _, _, itemType, _, _, equipLoc = GetItemInfo(linkOrID)
    return (itemType == "Armor" or itemType == "Weapon" or itemType == "Armadura" or itemType == "Arma") and equipLoc ~= ""
end

local function IsVersionNewer(remoteVer, localVer)
    if not remoteVer or not localVer then return false end
    local r1, r2, r3 = remoteVer:match("^(%d+)%.?(%d*)%.?(%d*)")
    local l1, l2, l3 = localVer:match("^(%d+)%.?(%d*)%.?(%d*)")
    r1, r2, r3 = tonumber(r1) or 0, tonumber(r2) or 0, tonumber(r3) or 0
    l1, l2, l3 = tonumber(l1) or 0, tonumber(l2) or 0, tonumber(l3) or 0
    if r1 ~= l1 then return r1 > l1 end
    if r2 ~= l2 then return r2 > l2 end
    return r3 > l3
end

function RDL_Core.BroadcastVersion(targetChannel, targetWhisper)
    local msg = "VER:" .. RDL_Core.VERSION
    if targetChannel then
        SendAddonMessage(ADDON_PREFIX, msg, targetChannel, targetWhisper)
        return
    end
    if IsInGuild() then SendAddonMessage(ADDON_PREFIX, msg, "GUILD") end
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(ADDON_PREFIX, msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(ADDON_PREFIX, msg, "PARTY")
    end
end

function RDL_Core.OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= ADDON_PREFIX or not msg or sender == UnitName("player") then return end
    local cmd, ver = msg:match("^(%u+):([%d%.]+)$")
    if not ver then return end

    if IsVersionNewer(ver, highestSeenVersion) then
        highestSeenVersion = ver
        if not updateNotified then
            updateNotified = true
            print(RDL_Theme.hexAccent .. "[Reinos de leyenda - Profesiones]|r ¡Nueva version disponible: |cffffffffv" .. ver .. "|r (tienes la v" .. RDL_Core.VERSION .. ").")
        end
    elseif cmd == "VER" and IsVersionNewer(RDL_Core.VERSION, ver) then
        RDL_Core.BroadcastVersion("WHISPER", sender)
    end
end

SLASH_RDLPROF1 = "/rdlprof"
SlashCmdList["RDLPROF"] = function()
    RDL_Core.BroadcastVersion()
    print(RDL_Theme.hexAccent .. "[Reinos de leyenda - Profesiones]|r Version instalada: |cffffffffv" .. RDL_Core.VERSION .. "|r (Maxima detectada: v" .. highestSeenVersion .. ").")
end

function RDL_Core.ClearCountCache() wipe(countCache) end

function RDL_Core.SetBankOpen(s)
    bankOpen = s
    if not s then pendingBankStoreID = nil; lastCraftedGearID = nil end
end

function RDL_Core.IsBankOpen() return bankOpen end
function RDL_Core.SetGuildBankOpen(s) guildBankOpen = s end

function RDL_Core.ScanBank()
    if not bankOpen then return end
    local t = {}
    for _, bag in ipairs(BANK_BAGS) do
        for s = 1, GetContainerNumSlots(bag) do
            local id = GetContainerItemID(bag, s)
            if id then local _, c = GetContainerItemInfo(bag, s); t[id] = (t[id] or 0) + (c or 1) end
        end
    end
    RDL_BankCache = t
    wipe(countCache)
end

function RDL_Core.ScanReagentVault()
    if not guildBankOpen then return end
    local tabName = GetGuildBankTabInfo(1) or ""
    if tabName ~= "Banco de Componentes" and tabName ~= "Reagent Bank" and IsInGuild() then return end
    local t = {}
    for s = 1, 98 do
        local link = GetGuildBankItemLink(1, s)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            local _, count = GetGuildBankItemInfo(1, s)
            if id then t[id] = (t[id] or 0) + (count or 1) end
        end
    end
    RDL_ReagentBankCache = t
    wipe(countCache)
end

function RDL_Core.GetBreakdownCounts(id)
    if not id then return 0, 0, 0 end
    local cached = countCache[id]
    if cached then return cached[1], cached[2], cached[3] end
    local inBags = GetItemCount(id, false) or 0
    local inPersonal = bankOpen and ((GetItemCount(id, true) or 0) - inBags) or (RDL_BankCache[id] or 0)
    local inVault = RDL_ReagentBankCache[id] or 0
    countCache[id] = { inBags, inPersonal, inVault }
    return inBags, inPersonal, inVault
end

function RDL_Core.TotalCount(id)
    local b, p, v = RDL_Core.GetBreakdownCounts(id)
    return b + p + v
end

local function FindFreeBankSlot()
    for _, bag in ipairs(BANK_BAGS) do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            if not GetContainerItemID(bag, slot) then return bag, slot end
        end
    end
    return nil, nil
end

function RDL_Core.TryStoreCraftedGearInBank()
    if not bankOpen or not pendingBankStoreID or InCombatLockdown() or CursorHasItem() then return end
    local movedAny = false
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if GetContainerItemID(bag, slot) == pendingBankStoreID then
                local _, _, locked = GetContainerItemInfo(bag, slot)
                if not locked then
                    local destBag, destSlot = FindFreeBankSlot()
                    if not destBag then pendingBankStoreID = nil; return end
                    PickupContainerItem(bag, slot)
                    PickupContainerItem(destBag, destSlot)
                    movedAny = true
                end
            end
        end
    end
    if movedAny then pendingBankStoreID = nil end
end

local function ScheduleNextCraft()
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.15 then
            self:SetScript("OnUpdate", nil)
            if qSpell and qRem > 0 then
                qRem = qRem - 1
                SendAddonMessage("RDL_CRAFT", qSpell .. ":1", "WHISPER", UnitName("player"))
            else
                qSpell, qName, qRem = nil, nil, 0
            end
        end
    end)
end

function RDL_Core.Craft(id, n)
    local _, _, avail = GetTradeSkillInfo(id)
    n = math.max(1, n or 1)
    lastCraftedGearID = nil
    local itemLink = id and id > 0 and GetTradeSkillItemLink(id)
    local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
    if itemID and RDL_Core.IsEquippableGear(itemLink) then lastCraftedGearID = itemID end

    if (avail or 0) >= n then DoTradeSkill(id, n); return end
    local link = GetTradeSkillRecipeLink(id) or ""
    local sp = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
    local skillName = GetTradeSkillInfo(id)
    if sp and skillName then
        qSpell, qName, qRem = tonumber(sp), skillName, n - 1
        timerFrame:SetScript("OnUpdate", nil)
        SendAddonMessage("RDL_CRAFT", sp .. ":1", "WHISPER", UnitName("player"))
    end
end

function RDL_Core.OnSpellSucceeded(spellName)
    if bankOpen and lastCraftedGearID then
        local sel = GetTradeSkillSelectionIndex()
        if spellName == qName or (sel and sel > 0 and spellName == GetTradeSkillInfo(sel)) then
            pendingBankStoreID = lastCraftedGearID
        end
    end
    if not qName or spellName ~= qName then return end
    local sel = GetTradeSkillSelectionIndex()
    if sel and sel > 0 then
        for i = 1, GetTradeSkillNumReagents(sel) do
            local _, _, req = GetTradeSkillReagentInfo(sel, i)
            local link = GetTradeSkillReagentItemLink(sel, i)
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if itemID and req and RDL_ReagentBankCache[itemID] then
                RDL_ReagentBankCache[itemID] = math.max(0, RDL_ReagentBankCache[itemID] - req)
            end
        end
    end
    wipe(countCache)
    if qRem > 0 then ScheduleNextCraft() else qSpell, qName, qRem = nil, nil, 0 end
end

function RDL_Core.OnSpellStopped(spellName)
    if qName and spellName == qName then
        timerFrame:SetScript("OnUpdate", nil)
        qSpell, qName, qRem = nil, nil, 0
    end
end
