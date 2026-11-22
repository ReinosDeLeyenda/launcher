local addonName, NS = ...

local COMM_PREFIX = "DBM"
local ADDON_TAG = "MODERNUI"
local msgQueue = {}
local lastRequestTime = {}
local commFrame = CreateFrame("Frame")
local sendTimer = 0
local initVerTimer = 0
local initVerSent = false
local lastVerBroadcast = 0

local CLASS_SPECIFIC_PROFS = {
    ["Venenos"] = true,
    ["Poisons"] = true,
    ["Forja de runas"] = true,
    ["Runeforging"] = true,
}

-- Recetas cuyo pergamino (Schematic/Pattern) tiene restricción de clase, pero el objeto creado no la muestra
local ITEM_CLASS_RESTRICTIONS = {
    [32495] = { PRIEST = true }, -- Powerheal 4000 Lens
    [35181] = { PRIEST = true }, -- Powerheal 9000 Lens
    [32494] = { MAGE = true, PRIEST = true, WARLOCK = true }, -- Destruction Holo-gogs
    [34353] = { MAGE = true, PRIEST = true, WARLOCK = true }, -- Hyper-Vision Goggles
    [34355] = { ROGUE = true, DRUID = true }, -- Quad Deathblow X44 Goggles
}

local RECIPE_NAME_CLASS_RESTRICTIONS = {
    ["Powerheal 4000 Lens"] = { PRIEST = true },
    ["Lente Powerheal 4000"] = { PRIEST = true },
    ["Powerheal 9000 Lens"] = { PRIEST = true },
    ["Lente Powerheal 9000"] = { PRIEST = true },
}

local CLASS_PRIMARY_ARMOR = {
    WARRIOR     = "Placas",
    PALADIN     = "Placas",
    DEATHKNIGHT = "Placas",
    HUNTER      = "Malla",
    SHAMAN      = "Malla",
    ROGUE       = "Cuero",
    DRUID       = "Cuero",
    MAGE        = "Tela",
    PRIEST      = "Tela",
    WARLOCK     = "Tela",
}

local CLASS_PRIMARY_ARMOR_EN = {
    WARRIOR     = "Plate",
    PALADIN     = "Plate",
    DEATHKNIGHT = "Plate",
    HUNTER      = "Mail",
    SHAMAN      = "Mail",
    ROGUE       = "Leather",
    DRUID       = "Leather",
    MAGE        = "Cloth",
    PRIEST      = "Cloth",
    WARLOCK     = "Cloth",
}

local ARMOR_TYPES = {
    ["Placas"] = true, ["Plate"] = true,
    ["Malla"]  = true, ["Mail"]  = true,
    ["Cuero"]  = true, ["Leather"] = true,
    ["Tela"]   = true, ["Cloth"] = true,
}

local scanTip = CreateFrame("GameTooltip", "MCUI_HiddenScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
local restrictedCache = {}

local function LineIsRestricted(text)
    if not text or text == "" then return false end
    if string.find(text, "Clases:", 1, true) or string.find(text, "Classes:", 1, true) then
        return true
    end
    if string.find(text, "Ingeniería gnómica", 1, true) or string.find(text, "Ingeniería goblin", 1, true)
        or string.find(text, "Gnomish Engineer", 1, true) or string.find(text, "Goblin Engineer", 1, true) then
        return true
    end
    return false
end

function NS.IsClassRestrictedRecipe(profName, link, recipeName)
    if profName and CLASS_SPECIFIC_PROFS[profName] then
        return true
    end

    local _, myClass = UnitClass("player")

    if recipeName and RECIPE_NAME_CLASS_RESTRICTIONS[recipeName] then
        return not RECIPE_NAME_CLASS_RESTRICTIONS[recipeName][myClass]
    end

    if not link then return false end

    local itemId = tonumber(string.match(link, "item:(%d+)"))
    if itemId and ITEM_CLASS_RESTRICTIONS[itemId] then
        return not ITEM_CLASS_RESTRICTIONS[itemId][myClass]
    end

    if restrictedCache[link] ~= nil then
        return restrictedCache[link]
    end

    scanTip:ClearLines()
    scanTip:SetHyperlink(link)

    local numLines = scanTip:NumLines()
    if not numLines or numLines == 0 then
        return false
    end

    local restricted = false
    local isBoP = false
    local foundArmorType = nil

    for i = 2, numLines do
        local left = _G["MCUI_HiddenScanTooltipTextLeft" .. i]
        local right = _G["MCUI_HiddenScanTooltipTextRight" .. i]
        local lText = left and left:GetText()
        local rText = right and right:GetText()

        if LineIsRestricted(lText) or LineIsRestricted(rText) then
            restricted = true
            break
        end

        if lText and (string.find(lText, "Se liga al recogerlo", 1, true) or string.find(lText, "Binds when picked up", 1, true)) then
            isBoP = true
        end
        if rText and ARMOR_TYPES[rText] then
            foundArmorType = rText
        end
    end

    if not restricted and isBoP and foundArmorType then
        local allowedEs = CLASS_PRIMARY_ARMOR[myClass]
        local allowedEn = CLASS_PRIMARY_ARMOR_EN[myClass]
        if foundArmorType ~= allowedEs and foundArmorType ~= allowedEn then
            restricted = true
        end
    end

    restrictedCache[link] = restricted
    return restricted
end

commFrame:SetScript("OnUpdate", function(self, elapsed)
    if not initVerSent then
        initVerTimer = initVerTimer + elapsed
        if initVerTimer >= 5 then
            initVerSent = true
            if NS.BroadcastVersion then NS.BroadcastVersion(true) end
        end
    end

    if #msgQueue == 0 then return end
    sendTimer = sendTimer + elapsed
    if sendTimer >= 0.35 then
        sendTimer = 0
        local item = table.remove(msgQueue, 1)
        if item and item.msg then
            if item.channel == "GUILD" and IsInGuild() then
                SendAddonMessage(COMM_PREFIX, item.msg, "GUILD")
            elseif item.channel == "RAID" and GetNumRaidMembers() > 0 then
                SendAddonMessage(COMM_PREFIX, item.msg, "RAID")
            elseif item.channel == "PARTY" and GetNumPartyMembers() > 0 then
                SendAddonMessage(COMM_PREFIX, item.msg, "PARTY")
            end
        end
    end
end)

local function QueueAddonMsg(payload, channel)
    local tagged = ADDON_TAG .. "|" .. payload
    for _, existing in ipairs(msgQueue) do
        if existing.msg == tagged and existing.channel == channel then return end
    end
    table.insert(msgQueue, { msg = tagged, channel = channel })
end

local function QueueGuildMessage(payload)
    if not IsInGuild() then return end
    QueueAddonMsg(payload, "GUILD")
end

function NS.GetAvailableProfessions()
    local profSet, sorted = {}, {}
    for pName in pairs(ModernCharacterUI_RecipesDB or {}) do
        if not CLASS_SPECIFIC_PROFS[pName] then profSet[pName] = true end
    end
    local rDB = ModernCharacterUI_GlobalDB[GetRealmName()] or {}
    local catalog = rDB._Catalog or {}
    for pName in pairs(catalog) do
        if not CLASS_SPECIFIC_PROFS[pName] then profSet[pName] = true end
    end
    for pName in pairs(profSet) do table.insert(sorted, pName) end
    table.sort(sorted)
    return sorted, profSet, catalog
end

function NS.RegisterCharacterRecipeInGlobal(charName, classFile, profName, recipeName, link, icon)
    if NS.IsClassRestrictedRecipe(profName, link, recipeName) then return end

    local realm = GetRealmName()
    ModernCharacterUI_GlobalDB[realm] = ModernCharacterUI_GlobalDB[realm] or {}
    local rDB = ModernCharacterUI_GlobalDB[realm]

    rDB._Catalog = rDB._Catalog or {}
    rDB._Catalog[profName] = rDB._Catalog[profName] or {}
    local existing = rDB._Catalog[profName][recipeName]
    rDB._Catalog[profName][recipeName] = {
        name = recipeName,
        link = link or (existing and existing.link),
        icon = icon or (existing and existing.icon)
    }

    if charName then
        rDB[charName] = rDB[charName] or { class = classFile, profs = {} }
        if classFile and classFile ~= "" then rDB[charName].class = classFile end
        rDB[charName].profs[profName] = rDB[charName].profs[profName] or {}
        rDB[charName].profs[profName][recipeName] = true
    end
end

local function PlayerKnowsRecipe(recipeName)
    for profName, recipes in pairs(ModernCharacterUI_RecipesDB or {}) do
        if not CLASS_SPECIFIC_PROFS[profName] then
            for _, rec in ipairs(recipes) do
                if rec.name == recipeName then return profName end
            end
        end
    end
    return nil
end

function NS.QueryRecipeInGuild(recipeName, forceRefresh)
    if not recipeName or not IsInGuild() then return end
    if forceRefresh then lastRequestTime[recipeName] = nil end
    local now = GetTime()
    if lastRequestTime[recipeName] and (now - lastRequestTime[recipeName]) < 15 then return end
    lastRequestTime[recipeName] = now
    QueueGuildMessage("ASK|" .. recipeName)
end

function NS.CheckRemoteVersion(remoteVer)
    if not remoteVer or remoteVer == "" then return false end
    local cmp = NS.CompareVersions and NS.CompareVersions(remoteVer, NS.latestVersion) or 0
    if cmp == 1 then
        NS.latestVersion = remoteVer
        NS.versionOutdated = true
        if not NS.versionNotified then
            NS.versionNotified = true
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[ModernUI]|r ¡Hay una nueva versión disponible! (|cff4ade80v%s|r - Tú tienes |cffff5555v%s|r).", remoteVer, NS.VERSION))
        end
        if NS.UpdateVersionBadgeUI then NS.UpdateVersionBadgeUI() end
    end
    return NS.CompareVersions and NS.CompareVersions(NS.VERSION, remoteVer) == 1
end

function NS.BroadcastVersion(force)
    if not NS.VERSION then return end
    local now = GetTime()
    if not force and (now - lastVerBroadcast) < 20 then return end
    lastVerBroadcast = now

    local payload = "VER|" .. NS.VERSION
    if IsInGuild() then
        QueueAddonMsg(payload, "GUILD")
    end
    if GetNumRaidMembers() > 0 then
        QueueAddonMsg(payload, "RAID")
    elseif GetNumPartyMembers() > 0 then
        QueueAddonMsg(payload, "PARTY")
    end
end

function NS.InitSkillsSync()
    if NS.PopulateStaticRecipeCatalog then NS.PopulateStaticRecipeCatalog() end

    local realm = GetRealmName()
    local rDB = ModernCharacterUI_GlobalDB and ModernCharacterUI_GlobalDB[realm]
    for profName in pairs(CLASS_SPECIFIC_PROFS) do
        if ModernCharacterUI_RecipesDB then ModernCharacterUI_RecipesDB[profName] = nil end
        if rDB then
            if rDB._Catalog then rDB._Catalog[profName] = nil end
            for charName, charData in pairs(rDB) do
                if charName ~= "_Catalog" and charData.profs then
                    charData.profs[profName] = nil
                end
            end
        end
    end

    local myName = UnitName("player")
    local _, myClass = UnitClass("player")
    for profName, recipes in pairs(ModernCharacterUI_RecipesDB or {}) do
        if not CLASS_SPECIFIC_PROFS[profName] then
            for _, rec in ipairs(recipes) do
                NS.RegisterCharacterRecipeInGlobal(myName, myClass, profName, rec.name, rec.link, rec.icon)
            end
        end
    end
    if IsInGuild() then GuildRoster() end
end

function NS.OnSkillsAddonMessage(prefix, msg, channel, sender)
    if prefix ~= COMM_PREFIX or not msg then return end
    local tag, cmd, arg1, arg2, arg3 = strsplit("|", msg)
    if tag ~= ADDON_TAG then return end

    local cleanSender = strsplit("-", sender)
    if cleanSender == UnitName("player") then return end

    if cmd == "VER" and arg1 then
        local iAmNewer = NS.CheckRemoteVersion(arg1)
        if iAmNewer then
            NS.BroadcastVersion(true)
        end
        return
    end

    if channel ~= "GUILD" then return end
    if cmd == "ASK" and arg1 then
        local profFound = PlayerKnowsRecipe(arg1)
        if profFound then
            local _, myClass = UnitClass("player")
            QueueGuildMessage("HAVE|" .. (myClass or "PRIEST") .. "|" .. profFound .. "|" .. arg1)
        end
        NS.BroadcastVersion()
    elseif cmd == "HAVE" and arg1 and arg2 and arg3 then
        if not CLASS_SPECIFIC_PROFS[arg2] then
            NS.RegisterCharacterRecipeInGlobal(cleanSender, arg1, arg2, arg3)
            if NS.OnCrafterUpdated then NS.OnCrafterUpdated(arg3) end
        end
    end
end

function NS.SaveCurrentTradeSkillRecipes()
    local profName = GetTradeSkillLine()
    if not profName or profName == "UNKNOWN" or CLASS_SPECIFIC_PROFS[profName] then return end

    local myName = UnitName("player")
    local _, myClass = UnitClass("player")
    local list = {}

    for i = 1, GetNumTradeSkills() do
        local skillName, skillType = GetTradeSkillInfo(i)
        if skillName and skillType ~= "header" and skillType ~= "subheader" then
            local iLink = GetTradeSkillItemLink(i) or GetTradeSkillRecipeLink(i)
            local icon = GetTradeSkillIcon(i)
            if not NS.IsClassRestrictedRecipe(profName, iLink, skillName) then
                table.insert(list, { name = skillName, type = skillType, link = iLink, icon = icon })
                NS.RegisterCharacterRecipeInGlobal(myName, myClass, profName, skillName, iLink, icon)
            end
        end
    end
    ModernCharacterUI_RecipesDB[profName] = list
end
