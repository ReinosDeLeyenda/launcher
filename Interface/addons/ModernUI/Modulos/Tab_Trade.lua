local addonName, NS = ...
local inspectStyled = false

local function StyleTradeUI()
    if not TradeFrame then return end

    NS.CreateMainWindowBG(TradeFrame, "ModernTradeMainBG", {
        portraits = { TradeFramePlayerPortrait, TradeFrameRecipientPortrait },
        right = -28, bottom = 48,
        closeBtn = TradeFrameCloseButton,
        titles = { TradeFramePlayerNameText, TradeFrameRecipientNameText }
    })

    for i = 1, MAX_TRADE_ITEMS or 7 do
        for _, prefix in ipairs({ "TradePlayerItem", "TradeRecipientItem" }) do
            local slot = _G[prefix .. i]
            if slot then
                NS.CleanFrameTextures(slot)
                NS.ApplyIceBackdrop(slot, 0.55)
                NS.TintFrameRegions(_G[prefix .. i .. "ItemButton"])
            end
        end
    end

    for _, box in ipairs({ TradePlayerInputMoneyFrameGold, TradePlayerInputMoneyFrameSilver, TradePlayerInputMoneyFrameCopper }) do
        NS.StyleEditBox(box)
    end
    NS.TintButtons({ TradeFrameTradeButton, TradeFrameCancelButton })
end

local function StyleInspectUI()
    if inspectStyled or not InspectFrame then return end
    inspectStyled = true

    NS.CreateMainWindowBG(InspectFrame, "ModernInspectMainBG", {
        portraits = { InspectFramePortrait },
        closeBtn = InspectFrameCloseButton,
        titles = { InspectNameText }
    })
    if InspectLevelText then InspectLevelText:SetTextColor(0.85, 0.96, 1.0) end

    for _, sf in ipairs({ InspectPaperDollFrame, InspectPVPFrame, InspectTalentFrame }) do
        NS.CleanFrameTextures(sf)
    end
    NS.StyleTabs("InspectFrameTab", 3, 0.90)
end

function NS.InitTradeTheme()
    StyleTradeUI()
    NS.RegisterTheme("Blizzard_InspectUI", StyleInspectUI)
end
