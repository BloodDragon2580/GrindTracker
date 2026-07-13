local addonName, addonTable = ...
local GrindTracker = LibStub("AceAddon-3.0"):NewAddon("GrindTracker", "AceConsole-3.0", "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GrindTracker")

local defaults = {
    profile = {
        trackedItems = {},
        minimap = {
            hide = false,
        },
    }
}

local dataObject
local options = {
    name = "GrindTracker",
    handler = GrindTracker,
    type = "group",
    args = {
        minimapToggle = {
            type = "toggle",
            name = L["Show Minimap Button"] or "Minimap Button anzeigen",
            desc = L["Toggles the minimap button on or off."] or "Schaltet den Button an der Minimap ein oder aus.",
            width = "full",
            get = function(info) return not GrindTracker.db.profile.minimap.hide end,
            set = function(info, value)
                GrindTracker.db.profile.minimap.hide = not value
                if value then
                    icon:Show("GrindTracker")
                else
                    icon:Hide("GrindTracker")
                end
            end,
            order = 1,
        },
        description = {
            type = "description",
            name = L["\nClick on an item in the list below to remove it.\n\n|cFF00FF00TIP:|r You can also use |cFFFFFF00ALT + Right-Click|r on an item in your inventory to quickly add or remove it from the tracker.\n"],
            order = 2,
        },
        items = {
            type = "group",
            name = L["Tracked Items (Click to remove)"],
            inline = true,
            order = 3,
            args = {}
        },
        copyright = {
            type = "description",
            name = "\n\n|cFF888888© BloodDragon2580 / https://gaming-nexus.de|r",
            order = 99,
        }
    }
}

function GrindTracker:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GrindTrackerDB", defaults, true)
    
    dataObject = LDB:NewDataObject("GrindTracker", {
        type = "data source",
        text = "GrindTracker",
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        OnClick = function(_, button)
            if button == "RightButton" then
                GrindTracker:OpenSettings()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("GrindTracker", 1, 0.8, 0)
            tooltip:AddLine(" ")
            local hasItems = false
            for itemID, _ in pairs(GrindTracker.db.profile.trackedItems) do
                local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                if itemName then
                    local count = 0
                    if C_Item and C_Item.GetItemCount then
                        count = C_Item.GetItemCount(itemID, true)
                    else
                        count = GetItemCount(itemID, true)
                    end
                    tooltip:AddDoubleLine("|T" .. itemIcon .. ":16|t " .. itemLink, count, 1, 1, 1, 1, 1, 1)
                    hasItems = true
                end
            end
            if not hasItems then tooltip:AddLine(L["No items tracked."], 0.5, 0.5, 0.5) end
            tooltip:AddLine(" ")
            tooltip:AddLine(L["|cFF00FF00Right-Click:|r Open Settings"], 0.7, 0.7, 0.7)
        end,
    })

    icon:Register("GrindTracker", dataObject, self.db.profile.minimap)

    AceConfig:RegisterOptionsTable("GrindTracker", options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("GrindTracker", "GrindTracker")
    self:RegisterChatCommand("gt", "OpenSettings")

    self:RegisterEvent("BAG_UPDATE", "UpdateDisplay")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateDisplay")
    
    self:BuildOptionsList()
    
    local function OnBagItemClicked(self, button)
        if button == "RightButton" and IsAltKeyDown() then
            local bag = self.GetBagID and self:GetBagID() or (self:GetParent() and self:GetParent():GetID())
            local slot = self:GetID()
            
            if bag and slot then
                local itemID
                if C_Container and C_Container.GetContainerItemID then
                    itemID = C_Container.GetContainerItemID(bag, slot)
                else
                    itemID = GetContainerItemID(bag, slot)
                end
                
                if itemID then
                    if GrindTracker.db.profile.trackedItems[itemID] then
                        GrindTracker:RemoveItem(itemID)
                    else
                        GrindTracker:AddItem(itemID)
                    end
                end
            end
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

function GrindTracker:OpenSettings()
    if AceConfigDialog.OpenFrames["GrindTracker"] then
        AceConfigDialog:Close("GrindTracker")
    else
        AceConfigDialog:Open("GrindTracker")
    end
end

function GrindTracker:AddItem(input)
    local itemID = tonumber(input)
    if not itemID then
        local _, _, _, _, Id = string.find(input, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+)")
        itemID = tonumber(Id)
    end
    
    if itemID then
        self.db.profile.trackedItems[itemID] = true
        if not C_Item.IsItemDataCachedByID(itemID) then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        print("|cFF00FF00GrindTracker:|r " .. (L["Item added."] or "Item added."))
        self:BuildOptionsList()
        self:UpdateDisplay()
    else
        print("|cFF00FF00GrindTracker:|r " .. (L["Invalid input."] or "Invalid input."))
    end
end

function GrindTracker:RemoveItem(itemID)
    self.db.profile.trackedItems[itemID] = nil
    print("|cFF00FF00GrindTracker:|r " .. (L["Item removed."] or "Item removed."))
    self:BuildOptionsList()
    self:UpdateDisplay()
end

function GrindTracker:BuildOptionsList()
    options.args.items.args = {}
    local order = 1
    for itemID, _ in pairs(self.db.profile.trackedItems) do
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        if not itemName then itemName = string.format(L["Loading item... (%s)"] or "Loading item... (%s)", itemID) end
        options.args.items.args["item_"..itemID] = {
            type = "execute",
            name = itemName,
            image = itemIcon,
            desc = L["Click to remove from tracking."] or "Click to remove from tracking.",
            func = function() self:RemoveItem(itemID) end,
            order = order,
        }
        order = order + 1
    end
    AceConfigRegistry:NotifyChange("GrindTracker")
end

function GrindTracker:UpdateDisplay()
    local displayString = ""
    local numTracked = 0
    for itemID, _ in pairs(self.db.profile.trackedItems) do
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        if itemName then
            local count = 0
            if C_Item and C_Item.GetItemCount then
                count = C_Item.GetItemCount(itemID, true)
            else
                count = GetItemCount(itemID, true)
            end
            displayString = displayString .. string.format("|T%s:14|t %d  ", itemIcon, count)
            numTracked = numTracked + 1
        end
    end
    if numTracked == 0 then
        dataObject.text = L["GrindTracker: Empty"] or "GrindTracker: Empty"
    else
        dataObject.text = displayString
    end
end
