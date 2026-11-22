local addonName, addon = ...
addon.PREFIX = "DBM" -- Prefijo permitido por los filtros anti-spam de servidores 3.3.5a
addon.TAG = "ICELFD"
addon.ICE_R, addon.ICE_G, addon.ICE_B = 0.25, 0.75, 1.0
addon.VERSION = GetAddOnMetadata(addonName, "Version") or "3.4.2"
addon.latestVersion = addon.VERSION
addon.versionOutdated = false
addon.versionNotified = false

function addon.CompareVersions(v1, v2)
    -- Devuelve 1 si v1 > v2, -1 si v1 < v2, 0 si son iguales
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

addon.ilvlCache = {}
addon.gearCache = {}
addon.metaCache = {}
addon.roleCache = {}
addon.talentCache = {}
addon.dungeonPctCache = {}
addon.dungeonMaskCache = {}
addon.pendingDress = {}
addon.inspectQueue = {}
addon.debugMode = false

addon.VISIBLE_SLOTS = { 1, 3, 5, 6, 7, 10, 15, 16, 17, 19 }

function addon.InitDB()
    if type(IceLFD_DB) ~= "table" then
        IceLFD_DB = {}
    end
    IceLFD_DB.ilvl = IceLFD_DB.ilvl or {}
    IceLFD_DB.gear = IceLFD_DB.gear or {}
    IceLFD_DB.meta = IceLFD_DB.meta or {}
    IceLFD_DB.roles = IceLFD_DB.roles or {}
    IceLFD_DB.talents = IceLFD_DB.talents or {}
    IceLFD_DB.dungeonPct = IceLFD_DB.dungeonPct or {}
    IceLFD_DB.dungeonMask = IceLFD_DB.dungeonMask or {}

    addon.ilvlCache = IceLFD_DB.ilvl
    addon.gearCache = IceLFD_DB.gear
    addon.metaCache = IceLFD_DB.meta
    addon.roleCache = IceLFD_DB.roles
    addon.talentCache = IceLFD_DB.talents
    addon.dungeonPctCache = IceLFD_DB.dungeonPct
    addon.dungeonMaskCache = IceLFD_DB.dungeonMask
end

function addon.DebugPrint(msg)
    if addon.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[IceLFD]|r " .. tostring(msg))
    end
end

SLASH_ICELFD1 = "/icelfd"
SlashCmdList["ICELFD"] = function(cmd)
    cmd = string.lower(string.trim(cmd or ""))
    if cmd == "clear" then
        IceLFD_DB = { ilvl = {}, gear = {}, meta = {}, roles = {}, talents = {}, dungeonPct = {}, dungeonMask = {} }
        addon.InitDB()
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[IceLFD]|r Caché borrada.")
        return
    elseif cmd == "ver" or cmd == "version" then
        if addon.versionOutdated then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[IceLFD]|r Tu versión: |cffff5555v%s|r | Última detectada: |cff4ade80v%s|r (¡Desactualizado!).", addon.VERSION, addon.latestVersion))
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccff[IceLFD]|r Versión actual: |cff4ade80v%s|r (Al día).", addon.VERSION))
        end
        return
    end

    addon.debugMode = not addon.debugMode
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[IceLFD]|r Debug: " .. (addon.debugMode and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    if addon.debugMode then
        for g, lvl in pairs(addon.ilvlCache) do
            DEFAULT_CHAT_FRAME:AddMessage(" - " .. g .. " | iLvl:" .. lvl .. " | " .. (addon.metaCache[g] or "sin raza"))
        end
    end
end

local ScanTooltip = CreateFrame("GameTooltip", "IceLFD_ScanTooltip", nil, "GameTooltipTemplate")
ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function addon.PreloadItems(gearStr)
    if not gearStr or gearStr == "" then return end
    for itemIdStr in string.gmatch(gearStr, "(%d+)") do
        local id = tonumber(itemIdStr)
        if id and not GetItemInfo(id) then
            ScanTooltip:SetHyperlink("item:" .. id)
        end
    end
end

local function ColorizeFrame(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if tex and not string.find(tex, "Icons") and not string.find(tex, "UI%-LFG%-RoleIcon") then
                region:SetVertexColor(addon.ICE_R, addon.ICE_G, addon.ICE_B)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local childName = child:GetName() or ""
        if childName ~= "IceLFD_PartyFrame" and not string.find(childName, "CloseButton") then
            ColorizeFrame(child)
        end
    end
end

function addon.ApplyIceBlueTheme()
    if not LFDParentFrame then return end
    ColorizeFrame(LFDParentFrame)

    local specificTextures = {
        "LFDParentFrameBackground",
        "LFDQueueFrameBackground",
        "LFDQueueFrameRandomScrollFrameScrollBackground",
        "LFDQueueFrameSpecificListScrollFrameScrollBackground"
    }
    for _, texName in ipairs(specificTextures) do
        local tex = _G[texName]
        if tex and tex.SetVertexColor then
            tex:SetVertexColor(addon.ICE_R, addon.ICE_G, addon.ICE_B)
        end
    end

    if LFDParentFrameTitle then
        LFDParentFrameTitle:SetTextColor(0.6, 0.9, 1.0)
    end
end
