local addonName, NS = ...

local MODULE_LABELS = {
    Character    = "Ventana de Personaje (Equipo, iLvl, GS y Estadísticas)",
    Pets         = "Mascotas y Monturas (Catálogo integrado)",
    Reputation   = "Pestaña de Reputación (Tema Azul Hielo)",
    Tokens       = "Pestaña de Monedas y Emblemas (Tema Azul Hielo)",
    Skills       = "Profesiones y Recetas (Buscador en Hermandad)",
    QuestLog     = "Registro de Misiones (Tema Azul Hielo)",
    Interface    = "Opciones de Interfaz y Menús",
    Achievements = "Ventana de Logros",
    Bags         = "Bolsas y Banco",
    Loot         = "Botín y Dados de Grupo/Banda (Loot y Roll)",
    Guild        = "Ventana de Hermandad (Bloque doble independiente)",
    GuildBank    = "Banco de Hermandad (Bóvedas, registros e iconos)",
    SpellBook    = "Libro de Hechizos y Facultades",
    Talents      = "Árbol de Talentos",
    Glyphs       = "Ventana de Glifos (Mayores y Menores)",
    Social       = "Ventana Social (Amigos, Hermandad y Banda)",
    Mail         = "Buzón de Correo",
    Auction      = "Casa de Subastas",
    Dialogs      = "Cuadros de Diálogo y Confirmación",
    Vendors      = "Vendedores (Lista ampliada)",
    Tooltips     = "Tooltips (Descripciones emergentes)",
    Trade        = "Ventana de Comercio",
}

local optFrame = CreateFrame("Frame", "ModernUI_OptionsFrame", UIParent)
optFrame:SetSize(440, 548)
optFrame:SetPoint("CENTER")
optFrame:SetFrameStrata("DIALOG")
optFrame:SetMovable(true)
optFrame:EnableMouse(true)
optFrame:RegisterForDrag("LeftButton")
optFrame:SetScript("OnDragStart", optFrame.StartMoving)
optFrame:SetScript("OnDragStop", optFrame.StopMovingOrSizing)
optFrame:Hide()
table.insert(UISpecialFrames, "ModernUI_OptionsFrame")

NS.ApplyIceBackdrop(optFrame, 0.96, 0.05, 0.14, 0.25, 16, 4)
NS.AddTopGlow(optFrame, 52, 0.40, 4)

local title = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 18, -16)
title:SetText("|cff66ccffModernUI|r |cffffffff- Configuración de Módulos|r")

local verLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
verLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
verLabel:SetTextColor(0.65, 0.88, 1.0)

local closeBtn = CreateFrame("Button", nil, optFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -4, -4)

local divider = optFrame:CreateTexture(nil, "ARTWORK")
divider:SetTexture(0.45, 0.80, 1.0, 0.35)
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 14, -52)
divider:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -14, -52)

local checkButtons = {}

local function RefreshCheckboxes()
    local disabledMap = (ModernCharacterUI_GlobalDB and ModernCharacterUI_GlobalDB.disabledModules) or {}
    for _, cb in ipairs(checkButtons) do
        cb:SetChecked(not disabledMap[cb.modId])
    end
    if NS.versionOutdated then
        verLabel:SetText(string.format("Versión: |cffff5555v%s|r  |  ¡Nueva versión |cff4ade80v%s|r disponible!", NS.VERSION or "?", NS.latestVersion or "?"))
    else
        verLabel:SetText(string.format("Versión: |cff4ade80v%s|r  |  Marca o desmarca los módulos activos:", NS.VERSION or "?"))
    end
end

local function BuildModuleCheckboxes()
    if #checkButtons > 0 or not NS.MODULES_LIST then return end
    for idx, mod in ipairs(NS.MODULES_LIST) do
        local cb = CreateFrame("CheckButton", "ModernUI_ModCB_" .. mod.id, optFrame, "ChatConfigCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 18, -60 - ((idx - 1) * 21))
        cb.modId = mod.id

        local label = _G[cb:GetName() .. "Text"]
        if label then
            label:SetText("|cffffffff" .. mod.id .. "|r |cff99d6ff- " .. (MODULE_LABELS[mod.id] or mod.id) .. "|r")
            label:SetFontObject("GameFontHighlightSmall")
        end

        cb:SetScript("OnClick", function(self)
            ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
            ModernCharacterUI_GlobalDB.disabledModules = ModernCharacterUI_GlobalDB.disabledModules or {}
            if self:GetChecked() then
                ModernCharacterUI_GlobalDB.disabledModules[self.modId] = nil
            else
                ModernCharacterUI_GlobalDB.disabledModules[self.modId] = true
            end
        end)

        table.insert(checkButtons, cb)
    end
end

optFrame:SetScript("OnShow", function()
    BuildModuleCheckboxes()
    RefreshCheckboxes()
end)

local function CreateIceButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    NS.ApplyIceBackdrop(btn, 0.90, 0.08, 0.24, 0.42, 10, 2)
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(text)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.15, 0.42, 0.68, 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.08, 0.24, 0.42, 0.90)
    end)
    return btn
end

local btnAllOn = CreateIceButton(optFrame, "Activar Todos", 110, 24)
btnAllOn:SetPoint("BOTTOMLEFT", optFrame, "BOTTOMLEFT", 16, 16)
btnAllOn:SetScript("OnClick", function()
    ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
    ModernCharacterUI_GlobalDB.disabledModules = {}
    RefreshCheckboxes()
end)

local btnAllOff = CreateIceButton(optFrame, "Desactivar Todos", 118, 24)
btnAllOff:SetPoint("LEFT", btnAllOn, "RIGHT", 8, 0)
btnAllOff:SetScript("OnClick", function()
    ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
    ModernCharacterUI_GlobalDB.disabledModules = {}
    for _, mod in ipairs(NS.MODULES_LIST or {}) do
        ModernCharacterUI_GlobalDB.disabledModules[mod.id] = true
    end
    RefreshCheckboxes()
end)

local btnReload = CreateIceButton(optFrame, "|cff7dd3fcAplicar (/reload)|r", 136, 24)
btnReload:SetPoint("BOTTOMRIGHT", optFrame, "BOTTOMRIGHT", -16, 16)
btnReload:SetScript("OnClick", function()
    ReloadUI()
end)

function NS.ToggleOptionsPanel()
    if optFrame:IsShown() then
        optFrame:Hide()
    else
        optFrame:Show()
    end
end

-- Registro en Interfaz -> Accesorios de Blizzard
local blizPanel = CreateFrame("Frame", "ModernUI_BlizOptionsPanel")
blizPanel.name = "ModernUI"
local blizTitle = blizPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
blizTitle:SetPoint("TOPLEFT", 16, -16)
blizTitle:SetText("|cff66ccffModernUI|r - Panel Modular")

local blizDesc = blizPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
blizDesc:SetPoint("TOPLEFT", blizTitle, "BOTTOMLEFT", 0, -8)
blizDesc:SetText("Pulsa el botón para abrir la ventana de configuración azul hielo o usa /modernui.")

local openBtn = CreateFrame("Button", nil, blizPanel, "UIPanelButtonTemplate")
openBtn:SetSize(180, 26)
openBtn:SetPoint("TOPLEFT", blizDesc, "BOTTOMLEFT", 0, -14)
openBtn:SetText("Abrir Configuración")
openBtn:SetScript("OnClick", function()
    InterfaceOptionsFrameCancel:Click()
    optFrame:Show()
end)
InterfaceOptions_AddCategory(blizPanel)

-- =========================================================================
-- BOTÓN DEL MINIMAPA (Arrastrable alrededor del borde)
-- =========================================================================
local miniBtn = CreateFrame("Button", "ModernUI_MinimapButton", Minimap)
miniBtn:SetSize(31, 31)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(8)
miniBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local miniBg = miniBtn:CreateTexture(nil, "BACKGROUND")
miniBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
miniBg:SetSize(25, 25)
miniBg:SetPoint("CENTER", 0, 1)

local miniIcon = miniBtn:CreateTexture(nil, "ARTWORK")
miniIcon:SetTexture("Interface\\Icons\\Spell_Frost_FrostNova")
miniIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
miniIcon:SetSize(20, 20)
miniIcon:SetPoint("CENTER", 0, 1)

local miniBorder = miniBtn:CreateTexture(nil, "OVERLAY")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
miniBorder:SetSize(53, 53)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetVertexColor(0.45, 0.85, 1.0)

local function UpdateMinimapButtonPos()
    local angle = (ModernCharacterUI_GlobalDB and ModernCharacterUI_GlobalDB.minimapAngle) or 210
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    miniBtn:ClearAllPoints()
    miniBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

miniBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
miniBtn:RegisterForDrag("LeftButton")

miniBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        ModernCharacterUI_GlobalDB = ModernCharacterUI_GlobalDB or {}
        ModernCharacterUI_GlobalDB.minimapAngle = angle
        UpdateMinimapButtonPos()
    end)
end)

miniBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

miniBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        ToggleCharacter("PaperDollFrame")
    else
        NS.ToggleOptionsPanel()
    end
end)

miniBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("|cff66ccffModernUI|r |cffffffffv" .. (NS.VERSION or "2.1") .. "|r")
    if NS.versionOutdated then
        GameTooltip:AddLine(string.format("|cffff5555¡Actualización disponible: v%s!|r", NS.latestVersion), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffffffClic Izquierdo:|r Configurar módulos", 0.75, 0.90, 1.0)
    GameTooltip:AddLine("|cffffffffClic Derecho:|r Abrir ventana de personaje", 0.75, 0.90, 1.0)
    GameTooltip:AddLine("|cffffffffArrastrar:|r Mover botón", 0.60, 0.80, 0.95)
    GameTooltip:Show()
end)

miniBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function NS.InitOptionsAndMinimap()
    UpdateMinimapButtonPos()
end
