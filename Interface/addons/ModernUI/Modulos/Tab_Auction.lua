local addonName, NS = ...
local styled = false

local function StyleAuctionUI()
    if styled or not AuctionFrame then return end
    styled = true

    NS.CreateMainWindowBG(AuctionFrame, "ModernAuctionMainBG", {
        portraits = { AuctionPortraitTexture },
        right = -6, bottom = 8,
        closeBtn = AuctionFrameCloseButton
    })

    NS.StyleTabs("AuctionFrameTab", 3, 0.90)

    for _, sf in ipairs({ AuctionFrameBrowse, AuctionFrameBid, AuctionFrameAuctions }) do
        NS.CleanFrameTextures(sf)
    end

    for _, sc in ipairs({ BrowseFilterScrollFrame, BrowseScrollFrame, BidScrollFrame, AuctionsScrollFrame }) do
        NS.StyleScrollFrameBox(sc, 0.55)
    end

    local editBoxes = {
        BrowseName, BrowseMinLevel, BrowseMaxLevel,
        BrowseBidPriceGold, BrowseBidPriceSilver, BrowseBidPriceCopper,
        BidBidPriceGold, BidBidPriceSilver, BidBidPriceCopper,
        StartPriceGold, StartPriceSilver, StartPriceCopper,
        BuyoutPriceGold, BuyoutPriceSilver, BuyoutPriceCopper,
        AuctionsStackSizeEntry, AuctionsNumStacksEntry
    }
    for _, eb in ipairs(editBoxes) do
        NS.StyleEditBox(eb)
    end

    NS.TintButtons({
        BrowseSearchButton, BrowseResetButton, BrowseBidButton, BrowseBuyoutButton, BrowseCloseButton,
        BidBidButton, BidBuyoutButton, BidCloseButton,
        AuctionsCreateAuctionButton, AuctionsCancelAuctionButton, AuctionsCloseButton,
        AuctionsStackSizeMaxButton, AuctionsNumStacksMaxButton,
        BrowseDropDown, DurationDropDown, AuctionsItemButton
    })
end

function NS.InitAuctionTheme()
    NS.RegisterTheme("Blizzard_AuctionUI", StyleAuctionUI)
end
