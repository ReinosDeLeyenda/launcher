RDL_Theme = {
    mainBg      = { 0.06, 0.22, 0.38, 0.94 },
    mainBorder  = { 0.55, 0.90, 1.00, 1.00 },
    panelBg     = { 0.03, 0.13, 0.24, 0.88 },
    panelBorder = { 0.45, 0.85, 1.00, 0.95 },
    tabBg       = { 0.05, 0.14, 0.24, 0.95 },
    tabBorder   = { 0.28, 0.58, 0.80, 1.00 },
    tabActive   = { 0.65, 0.95, 1.00, 1.00 },
    hexTitle    = "|cff9beeff",
    hexAccent   = "|cff7ce0ff",
    hexText     = "|cffd4f4ff",
    hexHighlight= "|cff66e5ff"
}

function RDL_Theme.ApplyBackdrop(frame, isSubPanel, withGradient)
    local edge = isSubPanel and 12 or 16
    local pad = isSubPanel and 3 or 4

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edge,
        insets = { left = pad, right = pad, top = pad, bottom = pad }
    })

    local bg = isSubPanel and RDL_Theme.panelBg or RDL_Theme.mainBg
    local bd = isSubPanel and RDL_Theme.panelBorder or RDL_Theme.mainBorder
    frame:SetBackdropColor(unpack(bg))
    frame:SetBackdropBorderColor(unpack(bd))

    if withGradient and not frame.frostGrad then
        local grad = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        grad:SetPoint("TOPLEFT", pad, -pad)
        grad:SetPoint("BOTTOMRIGHT", -pad, pad)
        grad:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        grad:SetGradientAlpha("VERTICAL", 0.04, 0.14, 0.26, 0.20, 0.35, 0.78, 1.00, 0.32)
        frame.frostGrad = grad
    end
end

function RDL_Theme.CreateWindow(name, parent, w, h, strata, movable)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetSize(w, h)
    if strata then f:SetFrameStrata(strata) end
    RDL_Theme.ApplyBackdrop(f, false, true)

    if movable then
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
    end
    return f
end

function RDL_Theme.CreatePanel(parent, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    RDL_Theme.ApplyBackdrop(p, true, false)
    return p
end
