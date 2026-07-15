local addonName = ...
local GrindTracker = LibStub("AceAddon-3.0"):NewAddon("GrindTracker", "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GrindTracker")

local defaults = {
    profile = {
        trackedItems = {},
        minimap = { hide = false },
        window = { point = "CENTER", x = 0, y = 0, width = 520, height = 525 },
    }
}

local COLORS = {
    accent = { 0.84, 0.15, 0.42 },
    accentSoft = { 0.42, 0.07, 0.20 },
    background = { 0.035, 0.04, 0.055, 0.98 },
    panel = { 0.075, 0.08, 0.105, 0.98 },
    panelHover = { 0.12, 0.125, 0.16, 1 },
    border = { 0.25, 0.27, 0.34, 1 },
    text = { 0.92, 0.93, 0.96 },
    muted = { 0.58, 0.61, 0.69 },
    success = { 0.20, 0.85, 0.45 },
    danger = { 0.95, 0.25, 0.32 },
}

local dataObject
local ROW_HEIGHT = 48
local MAX_VISIBLE_ROWS = 7

local function SetBackdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bg))
    frame:SetBackdropBorderColor(unpack(border))
end

local function CreateText(parent, size, flags)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, size, flags or "")
    text:SetTextColor(unpack(COLORS.text))
    return text
end

local function CreateStyledButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    SetBackdrop(button, COLORS.panel, COLORS.border)

    button.label = CreateText(button, 12, "OUTLINE")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.panelHover))
        self:SetBackdropBorderColor(unpack(COLORS.accent))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.panel))
        self:SetBackdropBorderColor(unpack(COLORS.border))
    end)
    return button
end

function GrindTracker:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GrindTrackerDB", defaults, true)

    dataObject = LDB:NewDataObject("GrindTracker", {
        type = "data source",
        text = "GrindTracker",
        icon = "Interface\\AddOns\\GrindTracker\\Media\\Texture\\logo",
        OnClick = function(_, button)
            if button == "LeftButton" then
                GrindTracker:ToggleWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFFD6266CGrindTracker|r")
            tooltip:AddLine(" ")
            local hasItems = false
            for itemID in pairs(GrindTracker.db.profile.trackedItems) do
                local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                if itemName then
                    local count = C_Item.GetItemCount(itemID, true)
                    tooltip:AddDoubleLine("|T" .. itemIcon .. ":16|t " .. itemLink, count, 1, 1, 1, 1, 1, 1)
                    hasItems = true
                end
            end
            if not hasItems then
                tooltip:AddLine(L["No items tracked."] or "Keine Items werden verfolgt.", unpack(COLORS.muted))
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cFF31D976" .. L["Left-Click:"] .. "|r " .. L["Open menu"], 0.75, 0.75, 0.78)
        end,
    })

    icon:Register("GrindTracker", dataObject, self.db.profile.minimap)
    if self.db.profile.minimap.hide then
        icon:Hide("GrindTracker")
    else
        icon:Show("GrindTracker")
    end
    self:RegisterEvent("BAG_UPDATE", "UpdateDisplay")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateDisplay")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")

    for itemID in pairs(self.db.profile.trackedItems) do
        if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end

    self:CreateMainWindow()
    self:HookBagClicks()
    self:RefreshWindow()
    self:UpdateDisplay()
end

function GrindTracker:PrintMessage(message, color)
    color = color or COLORS.accent
    print(string.format("|cFFD6266CGrindTracker:|r |cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, message))
end

function GrindTracker:CreateMainWindow()
    if self.window then return end

    local frame = CreateFrame("Frame", "GrindTrackerMainFrame", UIParent, "BackdropTemplate")
    local saved = self.db.profile.window
    frame:SetSize(saved.width or 520, saved.height or 525)
    frame:SetResizeBounds(430, 380, 900, 850)
    frame:SetResizable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    SetBackdrop(frame, COLORS.background, COLORS.accent)

    frame:SetPoint(saved.point or "CENTER", UIParent, saved.point or "CENTER", saved.x or 0, saved.y or 0)

    frame:SetScript("OnDragStart", frame.StartMoving)
    local function SaveWindowGeometry(self)
        local point, _, _, x, y = self:GetPoint(1)
        local settings = GrindTracker.db.profile.window
        settings.point = point or "CENTER"
        settings.x = x or 0
        settings.y = y or 0
        settings.width = math.floor(self:GetWidth() + 0.5)
        settings.height = math.floor(self:GetHeight() + 0.5)
    end

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowGeometry(self)
    end)
    frame:SetScript("OnSizeChanged", function(self, width, height)
        if self.content then
            self.content:SetWidth(math.max(1, width - 55))
        end
    end)
    frame:SetScript("OnShow", function()
        GrindTracker:RefreshWindow()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    end)
    frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE) end)

    table.insert(UISpecialFrames, "GrindTrackerMainFrame")

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(72)
    SetBackdrop(header, COLORS.panel, COLORS.accentSoft)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(58, 58)
    logo:SetPoint("LEFT", 10, 0)
    logo:SetTexture("Interface\\AddOns\\GrindTracker\\Media\\Texture\\logo")

    local title = CreateText(header, 21, "OUTLINE")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText("|cFFD6266CGrind|rTracker")

    local subtitle = CreateText(header, 11)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetTextColor(unpack(COLORS.muted))
    subtitle:SetText(L["Keep an eye on your farmed items at all times."])

    local close = CreateFrame("Button", nil, header)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    close:SetScript("OnClick", function() frame:Hide() end)

    local addPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    addPanel:SetPoint("TOPLEFT", 14, -86)
    addPanel:SetPoint("TOPRIGHT", -14, -86)
    addPanel:SetHeight(72)
    SetBackdrop(addPanel, COLORS.panel, COLORS.border)

    local addLabel = CreateText(addPanel, 11, "OUTLINE")
    addLabel:SetPoint("TOPLEFT", 12, -9)
    addLabel:SetTextColor(unpack(COLORS.muted))
    addLabel:SetText(L["ADD ITEM LINK OR ITEM ID"])

    local minimapToggle = CreateFrame("CheckButton", nil, addPanel, "UICheckButtonTemplate")
    minimapToggle:SetSize(22, 22)
    minimapToggle:SetPoint("TOPRIGHT", -10, -3)
    minimapToggle:SetChecked(not self.db.profile.minimap.hide)

    local minimapLabel = CreateText(addPanel, 10)
    minimapLabel:SetPoint("RIGHT", minimapToggle, "LEFT", -2, 0)
    minimapLabel:SetTextColor(unpack(COLORS.muted))
    minimapLabel:SetText(L["MINIMAP BUTTON"])

    minimapToggle:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        GrindTracker.db.profile.minimap.hide = not show
        if show then
            icon:Show("GrindTracker")
        else
            icon:Hide("GrindTracker")
        end
    end)
    minimapToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Show Minimap Button"])
        GameTooltip:AddLine(L["The Titan Panel entry remains unaffected."], 0.75, 0.75, 0.78)
        GameTooltip:Show()
    end)
    minimapToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local input = CreateFrame("EditBox", nil, addPanel, "BackdropTemplate")
    input:SetPoint("BOTTOMLEFT", 12, 10)
    input:SetPoint("BOTTOMRIGHT", -106, 10)
    input:SetHeight(30)
    input:SetAutoFocus(false)
    input:SetFont(STANDARD_TEXT_FONT, 12, "")
    input:SetTextColor(unpack(COLORS.text))
    input:SetTextInsets(10, 10, 0, 0)
    SetBackdrop(input, COLORS.background, COLORS.border)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    input:SetScript("OnEnterPressed", function(self)
        GrindTracker:AddItem(self:GetText())
        self:SetText("")
        self:ClearFocus()
    end)
    input:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(COLORS.accent)) end)
    input:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(COLORS.border)) end)

    local addButton = CreateStyledButton(addPanel, 84, 30, L["Add"])
    addButton:SetPoint("BOTTOMRIGHT", -12, 10)
    addButton:SetScript("OnClick", function()
        GrindTracker:AddItem(input:GetText())
        input:SetText("")
        input:ClearFocus()
    end)

    local listTitle = CreateText(frame, 13, "OUTLINE")
    listTitle:SetPoint("TOPLEFT", 18, -174)
    listTitle:SetText(L["TRACKED ITEMS"])

    frame.itemCount = CreateText(frame, 12, "OUTLINE")
    frame.itemCount:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    frame.itemCount:SetPoint("TOP", frame, "TOP", 0, -174)
    frame.itemCount:SetTextColor(unpack(COLORS.accent))

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -198)
    scroll:SetPoint("BOTTOMRIGHT", -34, 71)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(math.max(1, frame:GetWidth() - 55), ROW_HEIGHT * MAX_VISIBLE_ROWS)
    scroll:SetScrollChild(content)

    frame.scroll = scroll
    frame.content = content
    frame.rows = {}

    frame.emptyText = CreateText(frame, 14, "OUTLINE")
    frame.emptyText:SetPoint("TOPLEFT", scroll, "TOPLEFT", 20, -26)
    frame.emptyText:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -20, 20)
    frame.emptyText:SetTextColor(unpack(COLORS.muted))
    frame.emptyText:SetText(L["No items added yet."] .. "\n\n|cff8d93a3" .. L["ALT + Right-Click in inventory -> Add/remove item"] .. "|r\n|cff8d93a3" .. L["SHIFT + Left-Click an item -> Link in chat"] .. "|r")
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetJustifyV("TOP")
    frame.emptyText:SetWordWrap(true)

    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(58)
    SetBackdrop(footer, COLORS.panel, COLORS.accentSoft)

    local hint = CreateText(footer, 10)
    hint:SetPoint("LEFT", 14, 0)
    hint:SetPoint("RIGHT", -140, 0)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("MIDDLE")
    hint:SetWordWrap(true)
    hint:SetTextColor(unpack(COLORS.muted))
    hint:SetText(L["ALT + Right-Click in inventory -> Add/remove item"] .. "\n" .. L["SHIFT + Left-Click an item -> Link in chat"])

    local closeButton = CreateStyledButton(footer, 112, 26, L["Close window"])
    closeButton:SetPoint("RIGHT", -12, 0)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(22, 22)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveWindowGeometry(frame)
        GrindTracker:RefreshWindow()
    end)
    resizeGrip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L["Resize window"])
        GameTooltip:AddLine(L["Drag while holding the left mouse button."], 0.75, 0.75, 0.78)
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.content = content
    self.window = frame
end

function GrindTracker:CreateItemRow(index)
    local row = CreateFrame("Button", nil, self.window.content, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT - 4)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -2, -((index - 1) * ROW_HEIGHT))
    SetBackdrop(row, COLORS.panel, COLORS.border)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", 8, 0)

    row.name = CreateText(row, 12, "OUTLINE")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -3)
    row.name:SetPoint("RIGHT", -112, 0)
    row.name:SetJustifyH("LEFT")

    row.id = CreateText(row, 10)
    row.id:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 3)
    row.id:SetTextColor(unpack(COLORS.muted))

    row.count = CreateText(row, 16, "OUTLINE")
    row.count:SetPoint("RIGHT", -48, 0)
    row.count:SetTextColor(unpack(COLORS.accent))

    row.remove = CreateFrame("Button", nil, row)
    row.remove:SetSize(24, 24)
    row.remove:SetPoint("RIGHT", -10, 0)
    row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    row.remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.panelHover))
        self:SetBackdropBorderColor(unpack(COLORS.accent))
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.panel))
        self:SetBackdropBorderColor(unpack(COLORS.border))
        GameTooltip:Hide()
    end)

    self.window.rows[index] = row
    return row
end

function GrindTracker:RefreshWindow()
    if not self.window then return end

    local items = {}
    for itemID in pairs(self.db.profile.trackedItems) do
        local itemName, itemLink, quality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        table.insert(items, {
            id = itemID,
            name = itemName or string.format(L["Loading item... (%s)"] or "Lade Item... (%s)", itemID),
            link = itemLink,
            quality = quality,
            icon = itemIcon or 134400,
            count = C_Item.GetItemCount(itemID, true),
        })
    end

    table.sort(items, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)

    self.window.itemCount:SetText(string.format(L["%d item(s)"], #items))
    self.window.emptyText:SetShown(#items == 0)

    for index, item in ipairs(items) do
        local row = self.window.rows[index] or self:CreateItemRow(index)
        row:Show()
        row.itemID = item.id
        row.icon:SetTexture(item.icon)
        row.name:SetText(item.link or item.name)
        row.id:SetText(L["Item ID:"] .. " " .. item.id)
        row.count:SetText(item.count)
        row.remove:SetScript("OnClick", function() GrindTracker:RemoveItem(item.id) end)
        row:SetScript("OnClick", function(_, button)
            if button == "LeftButton" and IsShiftKeyDown() and item.link then
                ChatEdit_InsertLink(item.link)
            end
        end)
    end

    for index = #items + 1, #self.window.rows do
        self.window.rows[index]:Hide()
    end

    self.window.content:SetHeight(math.max(1, #items) * ROW_HEIGHT)
end

function GrindTracker:ToggleWindow()
    if not self.window then self:CreateMainWindow() end
    if self.window:IsShown() then self.window:Hide() else self.window:Show() end
end

function GrindTracker:OpenSettings()
    self:ToggleWindow()
end

function GrindTracker:AddItem(input)
    input = strtrim(tostring(input or ""))
    local itemID = tonumber(input)
    if not itemID then
        itemID = tonumber(input:match("item:(%d+)")) or tonumber(input:match("Hitem:(%d+)"))
    end

    if not itemID then
        self:PrintMessage(L["Invalid input."] or "Ungültige Eingabe.", COLORS.danger)
        return
    end

    if self.db.profile.trackedItems[itemID] then
        self:PrintMessage(L["This item is already being tracked."], COLORS.muted)
        return
    end

    self.db.profile.trackedItems[itemID] = true
    if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    self:PrintMessage(L["Item added."] or "Item hinzugefügt.", COLORS.success)
    self:RefreshWindow()
    self:UpdateDisplay()
end

function GrindTracker:RemoveItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or not self.db.profile.trackedItems[itemID] then return end
    self.db.profile.trackedItems[itemID] = nil
    self:PrintMessage(L["Item removed."] or "Item entfernt.", COLORS.danger)
    self:RefreshWindow()
    self:UpdateDisplay()
end

function GrindTracker:OnItemInfoReceived(_, itemID)
    if itemID and self.db.profile.trackedItems[itemID] then
        self:RefreshWindow()
        self:UpdateDisplay()
    end
end

function GrindTracker:UpdateDisplay()
    if not dataObject or not self.db then return end

    local parts = {}
    for itemID in pairs(self.db.profile.trackedItems) do
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        if itemName then
            local count = C_Item.GetItemCount(itemID, true)
            table.insert(parts, { id = itemID, text = string.format("|T%s:14|t %d", itemIcon, count) })
        end
    end
    table.sort(parts, function(a, b) return a.id < b.id end)

    if #parts == 0 then
        dataObject.text = L["GrindTracker: Empty"] or "GrindTracker: Leer"
    else
        local texts = {}
        for _, part in ipairs(parts) do table.insert(texts, part.text) end
        dataObject.text = table.concat(texts, "  ")
    end

    if self.window and self.window:IsShown() then self:RefreshWindow() end
end

function GrindTracker:HookBagClicks()
    local function OnBagItemClicked(buttonFrame, button)
        if button ~= "RightButton" or not IsAltKeyDown() then return end
        local bag = buttonFrame.GetBagID and buttonFrame:GetBagID() or (buttonFrame:GetParent() and buttonFrame:GetParent():GetID())
        local slot = buttonFrame:GetID()
        if bag == nil or not slot then return end

        local itemID = C_Container.GetContainerItemID(bag, slot)
        if not itemID then return end

        if GrindTracker.db.profile.trackedItems[itemID] then
            GrindTracker:RemoveItem(itemID)
        else
            GrindTracker:AddItem(itemID)
        end
    end

    if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
        hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", OnBagItemClicked)
    elseif ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnClick then
        hooksecurefunc(ContainerFrameItemButtonMixin, "OnClick", OnBagItemClicked)
    elseif type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", OnBagItemClicked)
    end
end
