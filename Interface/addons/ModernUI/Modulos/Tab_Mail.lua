local addonName, NS = ...

function NS.InitMailTheme()
    if not MailFrame then return end

    NS.CreateMainWindowBG(MailFrame, "ModernMailMainBG", {
        portraits = { MailFramePortrait },
        closeBtn = InboxCloseButton,
        titles = { InboxTitleText, SendMailTitleText }
    })

    NS.StyleTabs("MailFrameTab", 2, 0.90)

    if InboxFrame then
        NS.CleanFrameTextures(InboxFrame)
        for i = 1, 7 do
            local item = _G["MailItem" .. i]
            if item then
                NS.CleanFrameTextures(item)
                NS.ApplyIceBackdrop(item, 0.60)
            end
        end
        NS.TintButtons({ InboxPrevPageButton, InboxNextPageButton })
    end

    if SendMailFrame then
        NS.CleanFrameTextures(SendMailFrame)
        for _, box in ipairs({ SendMailNameEditBox, SendMailSubjectEditBox, SendMailMoneyGold, SendMailMoneySilver, SendMailMoneyCopper }) do
            NS.StyleEditBox(box)
        end
        NS.StyleScrollFrameBox(SendMailScrollFrame, 0.75)
        if SendMailBodyEditBox then SendMailBodyEditBox:SetTextColor(0.92, 0.98, 1.0) end

        for i = 1, 12 do
            NS.TintFrameRegions(_G["SendMailAttachment" .. i])
        end
        NS.TintButtons({ SendMailMailButton, SendMailCancelButton })
    end

    if OpenMailFrame then
        NS.CreateMainWindowBG(OpenMailFrame, "ModernOpenMailBG", {
            portraits = { OpenMailFrameIcon },
            closeBtn = OpenMailCloseButton,
            titles = { OpenMailTitleText },
            alpha = 0.96, glowHeight = 44
        })
        NS.StyleScrollFrameBox(OpenMailScrollFrame, 0.78)

        for _, fs in ipairs({ OpenMailSenderLabel, OpenMailSender, OpenMailSubjectLabel, OpenMailSubject, OpenMailBodyText, OpenMailAttachmentText }) do
            if fs and fs.SetTextColor then fs:SetTextColor(0.92, 0.98, 1.0) end
        end
        NS.TintButtons({ OpenMailReplyButton, OpenMailDeleteButton, OpenMailCancelButton, OpenMailReportSpamButton })
    end
end
