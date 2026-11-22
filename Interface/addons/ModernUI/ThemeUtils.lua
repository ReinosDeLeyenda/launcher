local addonName, NS = ...

NS.Theme = {
    BG = { 0.05, 0.14, 0.25, 0.95 },
    BD = { 0.45, 0.82, 1.00, 1.00 },
    GLOW_BOT = { 0.08, 0.28, 0.48, 0.00 },
    GLOW_TOP = { 0.30, 0.70, 1.00, 0.38 },
    TINT = { 0.35, 0.78, 1.00 },
    TEXT_TITLE = { 0.75, 0.94, 1.00 },
    TEXT_BODY  = { 0.92, 0.98, 1.00 },
}

function NS.CleanFrameTextures(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

function NS.ApplyIceBackdrop(frame, bgAlpha, r, g, b, edgeSize, insets)
    if not frame or not frame.SetBackdrop then return end
    local pad = insets or 3
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edgeSize or 14,
        insets = { left = pad, right = pad, top = pad, bottom = pad }
    })
    local bg, bd = NS.Theme.BG, NS.Theme.BD
    frame:SetBackdropColor(r or bg[1], g or bg[2], b or bg[3], bgAlpha or bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

function NS.AddTopGlow(frame, height, topAlpha, pad)
    if not frame or frame.iceGlow then return end
    local p = pad or 3
    local b, t = NS.Theme.GLOW_BOT, NS.Theme.GLOW_TOP
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", p, -p)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -p, -p)
    glow:SetHeight(height or 44)
    glow:SetGradientAlpha("VERTICAL", b[1], b[2], b[3], b[4], t[1], t[2], t[3], topAlpha or t[4])
    frame.iceGlow = glow
end

function NS.TintIceTexture(tex, r, g, b)
    if not tex or not tex.SetVertexColor then return end
    local t = NS.Theme.TINT
    if tex.SetDesaturated then tex:SetDesaturated(true) end
    tex:SetVertexColor(r or t[1], g or t[2], b or t[3])
end

function NS.TintFrameRegions(frame, r, g, b)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local texPath = region:GetTexture()
            if texPath and not string.find(texPath, "Icons") then
                NS.TintIceTexture(region, r, g, b)
            end
        end
    end
end

function NS.TintButtons(buttonList, r, g, b)
    for _, btn in ipairs(buttonList) do
        NS.TintFrameRegions(btn, r, g, b)
    end
end

function NS.StyleScrollBar(scrollBar)
    if not scrollBar then return end
    NS.CleanFrameTextures(scrollBar)
    local name = scrollBar:GetName()
    if name then
        NS.TintFrameRegions(_G[name .. "ScrollUpButton"])
        NS.TintFrameRegions(_G[name .. "ScrollDownButton"])
    end
end

function NS.StyleScrollFrameBox(scrollFrame, bgAlpha)
    if not scrollFrame then return end
    NS.CleanFrameTextures(scrollFrame)
    if bgAlpha then
        NS.ApplyIceBackdrop(scrollFrame, bgAlpha)
    end
    local name = scrollFrame:GetName()
    if name then
        NS.StyleScrollBar(_G[name .. "ScrollBar"])
    end
end

function NS.StyleEditBox(box, bgAlpha)
    if not box then return end
    NS.CleanFrameTextures(box)
    NS.ApplyIceBackdrop(box, bgAlpha or 0.85)
    box:SetTextColor(0.95, 0.99, 1.0)
end

function NS.StyleTabs(prefix, count, bgAlpha)
    for i = 1, count do
        local tab = _G[prefix .. i]
        if tab then
            NS.CleanFrameTextures(tab)
            NS.ApplyIceBackdrop(tab, bgAlpha or 0.90)
            local txt = _G[tab:GetName() .. "Text"]
            if txt then txt:SetTextColor(0.85, 0.96, 1.0) end
        end
    end
end

-- Crea el fondo estándar de ventanas de Blizzard (Mail, Social, Talents, Vendors, etc.)
function NS.CreateMainWindowBG(parent, bgName, opts)
    if not parent then return nil end
    opts = opts or {}
    NS.CleanFrameTextures(parent)

    if opts.portraits then
        for _, p in ipairs(opts.portraits) do
            if p then p:Hide() end
        end
    end

    local bg = CreateFrame("Frame", bgName, parent)
    bg:SetFrameLevel(math.max(1, parent:GetFrameLevel() - 1))
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.left or 10, opts.top or -12)
    bg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", opts.right or -32, opts.bottom or 72)
    NS.ApplyIceBackdrop(bg, opts.alpha or 0.95)
    NS.AddTopGlow(bg, opts.glowHeight or 48)

    if opts.closeBtn then
        opts.closeBtn:ClearAllPoints()
        opts.closeBtn:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 2, 2)
    end

    if opts.titles then
        local c = NS.Theme.TEXT_TITLE
        for _, fs in ipairs(opts.titles) do
            if fs and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3]) end
        end
    end

    return bg
end

-- Gestiona tanto marcos ya cargados como AddOns LoadOnDemand de Blizzard
function NS.RegisterTheme(addonNameOrNil, styleFunc)
    if not addonNameOrNil or IsAddOnLoaded(addonNameOrNil) then
        styleFunc()
    else
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function(self, _, loadedAddon)
            if loadedAddon == addonNameOrNil then
                styleFunc()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end
