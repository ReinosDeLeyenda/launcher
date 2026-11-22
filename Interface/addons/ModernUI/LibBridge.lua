local addonName, NS = ...

local dummyLocale = setmetatable({}, {
    __index = function(_, key) return tostring(key) end
})

-- 1. Objeto puente para Ackis Recipe List (Recetas)
local arlAddon = { recipesByProf = {} }

function arlAddon:addTradeSkill(RecipeDB, SpellID, Skill, ItemID, Rarity, ProfSpellID)
    if not SpellID or not ProfSpellID then return end
    local profName = GetSpellInfo(ProfSpellID)
    if not profName then return end
    self.recipesByProf[profName] = self.recipesByProf[profName] or {}
    table.insert(self.recipesByProf[profName], {
        spellID = SpellID, itemID = ItemID, skill = Skill or 1
    })
end
function arlAddon:addTradeFlags() end
function arlAddon:addTradeAcquire() end

-- 2. Objeto puente para Collectinator (Mascotas y Monturas)
local collectAddon = {
    mounts = {},
    critters = {},
    lookups = { vendor = {}, mob = {}, quest = {}, rep = {}, season = {}, custom = {} }
}

function collectAddon:addLookupList(DB, id, name, zone, x, y)
    if DB and id then DB[id] = { name = name, zone = zone, x = x, y = y } end
end

function collectAddon:AddCompanion(DB, cType, SpellID, ItemID, Rarity, Game, Class)
    if not SpellID then return end
    DB[SpellID] = {
        type = cType, spellID = SpellID, itemID = ItemID,
        rarity = Rarity, class = Class, flags = {}, acquire = {}
    }
end

function collectAddon:AddCompanionFlags(DB, SpellID, ...)
    local target = (type(DB) == "table") and DB[SpellID] or nil
    if not target then return end
    for i = 1, select("#", ...) do
        local flag = select(i, ...)
        if flag then target.flags[flag] = true end
    end
end

function collectAddon:AddCompanionAcquire(DB, SpellID, ...)
    local target = (type(DB) == "table") and DB[SpellID] or nil
    if not target then return end
    local i = 1
    while i <= select("#", ...) do
        local aType = select(i, ...)
        local id1 = select(i + 1, ...)
        local id2 = select(i + 2, ...)
        local id3 = select(i + 3, ...)
        if aType == 6 then
            table.insert(target.acquire, { type = aType, repID = id1, level = id2, vendorID = id3 })
            i = i + 4
        elseif aType == 3 then
            table.insert(target.acquire, { type = aType, profID = id1, spellID = id2 })
            i = i + 3
        else
            table.insert(target.acquire, { type = aType, id = id1 })
            i = i + 2
        end
    end
end

function collectAddon.IsCorrectFaction(myFaction, flags)
    if not flags then return true end
    local isAlliance = rawget(flags, 1)
    local isHorde = rawget(flags, 2)
    if isAlliance and isHorde then return true end
    if myFaction == "Alliance" and isAlliance then return true end
    if myFaction == "Horde" and isHorde then return true end
    return false
end

local function BuildSourceText(acqList)
    if not acqList or #acqList == 0 then return "Origen desconocido" end
    local first = rawget(acqList, 1)
    if not first then return "Origen desconocido" end
    local L = collectAddon.lookups
    local t = first.type

    if t == 1 then
        local v = L.vendor[first.id]
        return v and string.format("Vendedor: %s (%s)", v.name or "NPC", v.zone or "Zona") or "Vendedor"
    elseif t == 2 then
        local q = L.quest[first.id]
        return (q and q.zone) and ("Misión (" .. q.zone .. ")") or "Recompensa de Misión"
    elseif t == 3 then
        local prof = first.profID and GetSpellInfo(first.profID)
        return "Profesión: " .. (prof or "Artesanía")
    elseif t == 4 then
        local m = L.mob[first.id]
        return m and string.format("Drop: %s (%s)", m.name or "Jefe", m.zone or "Instancia") or "Botín de Jefe"
    elseif t == 5 then
        local s = L.season[first.id]
        return "Evento: " .. (s and s.name or "Estacional")
    elseif t == 6 then
        local r = L.rep[first.repID]
        local v = L.vendor[first.vendorID]
        local repName = (r and r.name) or "Reputación"
        return (v and v.zone) and string.format("Rep: %s (%s)", repName, v.zone) or ("Reputación: " .. repName)
    elseif t == 7 then
        return "Botín del mundo"
    elseif t == 8 then
        local c = L.custom[first.id]
        return (c and c.name) or "Especial / Promoción"
    elseif t == 9 then
        local _, achName = GetAchievementInfo(first.id or 0)
        return "Logro: " .. (achName or tostring(first.id or ""))
    end
    return "Origen desconocido"
end

local fakeBabble = {
    GetLookupTable = function()
        return setmetatable({ ["Alliance"] = "Alliance", ["Horde"] = "Horde" },
            { __index = function(_, k) return tostring(k) end })
    end
}

local function GetBridgeAddon(name)
    if name == "Ackis Recipe List" then return arlAddon end
    if name == "Collectinator" then return collectAddon end
end

if not _G.LibStub then
    _G.LibStub = setmetatable({}, {
        __call = function(_, libName)
            if libName == "AceAddon-3.0" then return { GetAddon = function(_, n) return GetBridgeAddon(n) end } end
            if libName == "AceLocale-3.0" then return { GetLocale = function() return dummyLocale end } end
            return fakeBabble
        end
    })
else
    local origLibStub = _G.LibStub
    _G.LibStub = setmetatable({}, {
        __index = origLibStub,
        __call = function(self, libName, silent)
            if libName == "LibBabble-Faction-3.0" or libName == "LibBabble-Zone-3.0" or libName == "LibBabble-Boss-3.0" then
                return fakeBabble
            end
            if libName == "AceLocale-3.0" then
                local ok, res = pcall(origLibStub, libName, true)
                if ok and res then
                    local origGetLocale = res.GetLocale
                    return setmetatable({
                        GetLocale = function(t, appName, s)
                            if appName == "Ackis Recipe List" or appName == "Collectinator" then return dummyLocale end
                            return origGetLocale(t, appName, s)
                        end
                    }, { __index = res })
                end
                return { GetLocale = function() return dummyLocale end }
            end
            if libName == "AceAddon-3.0" then
                local ok, res = pcall(origLibStub, libName, true)
                if ok and res then
                    local origGetAddon = res.GetAddon
                    return setmetatable({
                        GetAddon = function(t, appName, s)
                            local bridged = GetBridgeAddon(appName)
                            if bridged then return bridged end
                            return origGetAddon(t, appName, s)
                        end
                    }, { __index = res })
                end
                return { GetAddon = function(_, n) return GetBridgeAddon(n) end }
            end
            return origLibStub(libName, silent)
        end
    })
end

function NS.PopulateStaticRecipeCatalog()
    local initFuncs = {
        "InitAlchemy", "InitBlacksmithing", "InitCooking", "InitEnchanting",
        "InitEngineering", "InitFirstAid", "InitInscription", "InitJewelcrafting",
        "InitLeatherworking", "InitRuneforging", "InitSmelting", "InitTailoring"
    }
    local dummyDB = {}
    for _, fnName in ipairs(initFuncs) do
        if type(arlAddon[fnName]) == "function" then pcall(arlAddon[fnName], arlAddon, dummyDB) end
    end

    local realm = GetRealmName()
    ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
    ModernCharacterUI_GlobalDB[realm] = ModernCharacterUI_GlobalDB[realm] or {}
    ModernCharacterUI_GlobalDB[realm]._Catalog = ModernCharacterUI_GlobalDB[realm]._Catalog or {}
    local rCat = ModernCharacterUI_GlobalDB[realm]._Catalog

    for profName, entries in pairs(arlAddon.recipesByProf) do
        rCat[profName] = rCat[profName] or {}
        for _, entry in ipairs(entries) do
            local rName, _, rIcon = GetSpellInfo(entry.spellID)
            if rName and not rCat[profName][rName] then
                local itemLink = entry.itemID and select(2, GetItemInfo(entry.itemID))
                local spellLink = string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", entry.spellID, rName)
                rCat[profName][rName] = { name = rName, link = itemLink or spellLink, icon = rIcon }
            end
        end
    end
end

local companionsBuilt = false
function NS.GetCompanionCatalog(mode)
    if not companionsBuilt then
        local L = collectAddon.lookups
        if collectAddon.InitVendor then pcall(collectAddon.InitVendor, collectAddon, L.vendor) end
        if collectAddon.InitMob then pcall(collectAddon.InitMob, collectAddon, L.mob) end
        if collectAddon.InitQuest then pcall(collectAddon.InitQuest, collectAddon, L.quest) end
        if collectAddon.InitReputation then pcall(collectAddon.InitReputation, collectAddon, L.rep) end
        if collectAddon.InitSeasons then pcall(collectAddon.InitSeasons, collectAddon, L.season) end
        if collectAddon.InitCustom then pcall(collectAddon.InitCustom, collectAddon, L.custom) end

        local mDB, pDB = {}, {}
        if collectAddon.GetMountTotal then pcall(collectAddon.GetMountTotal, collectAddon, mDB) end
        if collectAddon.GetMiniPetTotal then pcall(collectAddon.GetMiniPetTotal, collectAddon, pDB) end

        local myFaction = UnitFactionGroup("player")
        for spellID, data in pairs(mDB) do
            if collectAddon.IsCorrectFaction(myFaction, data.flags) then
                local name, _, icon = GetSpellInfo(spellID)
                if name then
                    table.insert(collectAddon.mounts, {
                        spellID = spellID, name = name, icon = icon, source = BuildSourceText(data.acquire)
                    })
                end
            end
        end
        for spellID, data in pairs(pDB) do
            if collectAddon.IsCorrectFaction(myFaction, data.flags) then
                local name, _, icon = GetSpellInfo(spellID)
                if name then
                    table.insert(collectAddon.critters, {
                        spellID = spellID, name = name, icon = icon, source = BuildSourceText(data.acquire)
                    })
                end
            end
        end
        table.sort(collectAddon.mounts, function(a, b) return a.name < b.name end)
        table.sort(collectAddon.critters, function(a, b) return a.name < b.name end)
        companionsBuilt = true
    end
    return (mode == "MOUNT") and collectAddon.mounts or collectAddon.critters
end