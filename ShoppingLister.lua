local _, SL = ...
local addonName = "ShoppingLister"
local SL = LibStub("AceAddon-3.0"):NewAddon(SL, addonName, "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName);

local defaults = {
    profile = {
        stripempty = true,
        trimwhitespace = false,
        windowscale = 1.0,
        shiftenter = false,
        settings = {
            discount = "90",
            priceSource = "DBMarket",
            fallback = "1000"
        }
    }
}

local settings = defaults.profile
local optionsFrame

local private = {
    tsmGroups = {},
    availableTsmGroups = {},
    settings = {groups = {}}
}

local function tooltip_draw(isAddonCompartment, blizzardTooltip)
  local tooltip
  if isAddonCompartment then
    tooltip = blizzardTooltip
  else
    tooltip = GameTooltip
  end
  tooltip:ClearLines()
  tooltip:AddDoubleLine(addonName, versionString)
  tooltip:AddLine(" ")
  tooltip:AddLine("|cffff8040" .. L["left_click"] .. "|r " .. L["toogle"])
  tooltip:AddLine("|cffff8040" .. L["right_click"] .. "|r " .. L["options"])
  tooltip:Show();
end

addon.GenerateTooltip = tooltip_draw;

function SL:GetOptions()
    return {
        type = "group",
        set = function(info, val)
            local s = settings;
            for i = 2, #info - 1 do s = s[info[i]] end
            s[info[#info]] = val;
            SL.Debug.Log(info[#info] .. " set to: " .. tostring(val))
            SL:Update()
        end,
        get = function(info)
            local s = settings;
            for i = 2, #info - 1 do s = s[info[i]] end
            return s[info[#info]]
        end,
        args = {
            general = {
                type = "group",
                inline = true,
                name = L["general"],
                args = {
                    config = {
                        name = L["config"],
                        desc = L["config_toggle"],
                        type = "execute",
                        guiHidden = true,
                        func = function() SL:Config() end
                    },
                    show = {
                        name = L["show"],
                        desc = L["show_toggle"],
                        type = "execute",
                        guiHidden = true,
                        func = function()
                            SL:ToggleWindow()
                        end
                    },
                    aheader = {
                        name = APPEARANCE_LABEL,
                        type = "header",
                        cmdHidden = true,
                        order = 300
                    },
                    windowscale = {
                        order = 310,
                        type = 'range',
                        name = L["window_scale"],
                        desc = L["window_scale_desc"],
                        min = 0.1,
                        max = 5,
                        step = 0.1,
                        bigStep = 0.1,
                        isPercent = true
                    }
                }
            }
        }
    }
end

function SL:RefreshConfig()
    -- things to do after load or settings are reset
    SL.Debug.Log("RefreshConfig")
    settings = SL.db.profile
    private.settings = settings

    for k, v in pairs(defaults.profile) do
        if settings[k] == nil then settings[k] = table_clone(v) end
    end

    settings.loaded = true

    SL:Update()
end

function SL:Update()
    -- things to do when settings changed

    if SL.gui then -- scale the window
        private.PrepareTsmGroups()
        private.UpdateValues()
        local frame = SL.gui.frame
        local old = frame:GetScale()
        local new = settings.windowscale

        if old ~= new then
            local top, left = frame:GetTop(), frame:GetLeft()
            frame:ClearAllPoints()
            frame:SetScale(new)
            left = left * old / new
            top = top * old / new
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end
end

function SL:OnInitialize()
    SL.db = LibStub("AceDB-3.0"):New("ShoppingListerDB", defaults, true)
    SL:RefreshConfig()

    local options = SL:GetOptions()
    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(options, addonName)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options,
                                                  {"shoppinglister"})

    optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName,
                                                                   addonName,
                                                                   nil,
                                                                   "general")
    optionsFrame.default = function()
        for k, v in pairs(defaults.profile) do
            settings[k] = table_clone(v)
        end

        SL:RefreshConfig()

        if SettingsPanel:IsShown() then
            SL:Config();
            SL:Config()
        end
    end

    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(SL.db)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Profiles",
                                                    addonName, "profiles")

    SL.Debug.Log("OnInitialize")

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    self.db.RegisterCallback(self, "OnDatabaseReset", "RefreshConfig")
    SL:RegisterChatCommand('sl', 'HandleChatCommand')
    SL:RegisterChatCommand('slist', 'HandleChatCommand')
    SL:RegisterChatCommand('shoppinglister', 'HandleChatCommand')

    private.PrepareTsmGroups()
    SL:RefreshConfig()

    AddonCompartmentFrame:RegisterAddon({
      text = addonName,
      registerForAnyClick = true,
      notCheckable = true,
      func = function(button, menuInputData, menu)
        local mouseButton = menuInputData.buttonName
        if mouseButton == "LeftButton" then
          SL:ToggleWindow()
        end
      end,
      funcOnEnter = function(button)
          MenuUtil.ShowTooltip(button, function(tooltip)
              addon.GenerateTooltip(true, tooltip)
          end)
      end,
      funcOnLeave = function(button) MenuUtil.HideTooltip(button) end
    })
end

function SL:HandleChatCommand(input)
    local args = {strsplit(' ', input)}

    for _, arg in ipairs(args) do
        if arg == 'help' then
            DEFAULT_CHAT_FRAME:AddMessage(L["default_chat_message"])
            return
        end
    end

    SL:ToggleWindow()
end

function SL:Config()
    if optionsFrame then
        if (SettingsPanel:IsShown()) then
            SettingsPanel:Hide();
        else
			Settings.OpenToCategory(addonName)
			SettingsPanel.AddOnsTab:Click()
        end
    end
end

function SL:OnEnable()
    SL.Debug.Log("OnEnable")
    SL:Print(format(L["welcome_message"], addonName))
    SL:Update()
end

function SL:ToggleWindow(keystate)
    if keystate == "down" then return end -- ensure keybind doesnt end up in the text box
    SL.Debug.Log("ToggleWindow")

    if not SL.gui then SL:CreateWindow() end

    if SL.gui:IsShown() then
        SL.gui:Hide()
    else
        SL.gui:Show()
        SL:Update()
    end
end

function SL:CreateWindow()
    if SL.gui then return end

    -- Create main window.
    local frame = AceGUI:Create("Frame")
    frame.frame:SetFrameStrata("MEDIUM")
    frame.frame:Raise()
    frame.content:SetFrameStrata("MEDIUM")
    frame.content:Raise()
    frame:Hide()
    SL.gui = frame
    frame:SetTitle(addonName)
    frame:SetCallback("OnClose", OnClose)
    frame:SetLayout("Fill")
    frame.frame:SetClampedToScreen(true)
    settings.pos = settings.pos or {}
    frame:SetStatusTable(settings.pos)
    SL.minwidth = 800
    SL.minheight = 200
    frame:SetWidth(SL.minwidth)
    frame:SetHeight(SL.minheight)
    frame:SetAutoAdjustHeight(true)
    private.SetEscapeHandler(frame, function() SL:ToggleWindow() end)

    -- Create main group, where everything is placed.
    local mainGroup = private.CreateGroup("List", frame)

    -- Create dropdown group, where everything is placed.
    local dropdownGroup = private.CreateGroup("Flow", mainGroup)

    local tsmGroup = private.CreateGroup("List", dropdownGroup)
    tsmGroup:SetFullWidth(false)
    tsmGroup:SetRelativeWidth(0.5)

    -- Create tsm dropdown
    local tsmDropdown = AceGUI:Create("Dropdown")
    tsmGroup:AddChild(tsmDropdown)
    SL.tsmDropdown = tsmDropdown
    tsmDropdown:SetMultiselect(false)
    tsmDropdown:SetLabel(L["tsm_groups_label"])
    tsmDropdown:SetRelativeWidth(0.5)
    tsmDropdown:SetCallback("OnValueChanged", function(widget, event, key)
        settings.settings.tsmDropdown = key
    end)

    -- Create tsm sub group checkbox
    local tsmSubgroups = AceGUI:Create("CheckBox")
    SL.tsmSubgroups = tsmSubgroups
    tsmGroup:AddChild(tsmSubgroups)
    tsmSubgroups:SetType("checkbox")
    tsmSubgroups:SetLabel(L["tsm_checkbox_label"])
    tsmSubgroups:SetValue(true)

    -- Shopping list name
    local slGroup = private.CreateGroup("List", dropdownGroup)
    slGroup:SetFullWidth(false)
    slGroup:SetRelativeWidth(0.5)
    local slName = AceGUI:Create("EditBox")
    SL.slName = slName
    slGroup:AddChild(slName)
    slName:SetLabel(L["sl_name_label"])
    slName:SetRelativeWidth(0.5)
    slName:DisableButton(true)

    -- AceGUI fails at enforcing minimum Frame resize for a container, so fix it
    hooksecurefunc(frame, "OnHeightSet", function(widget, height)
        if (widget ~= SL.gui) then return end
        if (height < SL.minheight) then frame:SetHeight(SL.minheight) end
    end)

    hooksecurefunc(frame, "OnWidthSet", function(widget, width)
        if (widget ~= SL.gui) then return end
        if (width < SL.minwidth) then frame:SetWidth(SL.minwidth) end
    end)

    -- Create group for the buttons
    local buttonsGroup = private.CreateGroup("Flow", mainGroup)

    local buttonWidth = 150
    local transformButton = AceGUI:Create("Button")
    transformButton:SetText(L["transform_button"])
    transformButton:SetWidth(buttonWidth)
    transformButton:SetCallback("OnClick", function(widget, button)
        private.Transform()
    end)
    buttonsGroup:AddChild(transformButton)

    local clearButton = AceGUI:Create("Button")
    clearButton:SetText(L["clear_button"])
    clearButton:SetWidth(buttonWidth)
    clearButton:SetCallback("OnClick", function(widget, button)
        if (SL.TSM.IsLoaded()) then SL.tsmDropdown:SetValue("") end
        SL.gui:SetStatusText("")
        SL.slName:SetText("")
    end)
    buttonsGroup:AddChild(clearButton)
end

-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CreateGroup(layout, parent)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout(layout)
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    parent:AddChild(group)
    return group
end

function private.ClearDropdown()
    SL.tsmDropdown:SetValue("")
    settings.settings.tsmDropdown = ""
end

function private.UpdateValues()
    SL.Debug.Log("UpdateValues")
    local widgetTsmDropdown = SL.tsmDropdown
    if widgetTsmDropdown and not widgetTsmDropdown.open then
        SL.Debug.Log("Setting tsm groups dropdown")
        widgetTsmDropdown:SetList(private.availableTsmGroups)
    end
end

function private.PrepareTsmGroups()
    SL.Debug.Log("PrepareTsmGroups()")

    -- price source check --
    local tsmGroups = SL.TSM.GetGroups() or {}
    SL.Debug.Log(format("loaded %d tsm groups", private.tablelength(tsmGroups)));

    -- only 2 or less price sources -> chat msg: missing modules
    if private.tablelength(tsmGroups) < 1 then
        StaticPopupDialogs["AT_NO_TSMGROUPS"] = {
            text = L["no_tsm_groups"],
            button1 = OKAY,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true
        }
        StaticPopup_Show("AT_NO_TSMGROUPS");

        SL:Print(L["addon_disabled"]);
        SL:Disable();
        return
    end

    private.tsmGroups = tsmGroups
    private.availableTsmGroups = {}

    for k, v in pairs(tsmGroups) do
        local parent, group = SL.TSM.SplitGroupPath(v)
        local _, c = v:gsub("`", "")

        if (parent ~= nil) then
            group = private.lpad(SL.TSM.FormatGroupPath(group), c * 4, " ")
        end
        table.insert(private.availableTsmGroups, k, group)
    end
end

function private.Transform()
    local selectedGroup = private.tsmGroups[private.GetFromDb("settings",
                                                              "tsmDropdown")]
    local subgroups = SL.tsmSubgroups:GetValue()

    SL.Debug.Log(
        "Transforming: " .. selectedGroup .. " including subgroups: " ..
            tostring(subgroups))
    if private.ProcessTSMGroup(selectedGroup, subgroups) then
        SL.gui:SetStatusText(L["status_text"])
        return true
    end

    return false
end

-- easy button system
function private.addonButton()
    local addonButton = CreateFrame("Button", "Shopping Lister", UIParent,
                                    "UIPanelButtonTemplate")
    addonButton:SetFrameStrata("HIGH")
    addonButton:SetSize(120, 22) -- width, height
    addonButton:SetText("Shopping Lister")
    addonButton:SetPoint("TOPRIGHT", "AuctionHouseFrame", "TOPRIGHT", -610, 0)

    -- make moveable
    addonButton:SetMovable(false)
    addonButton:EnableMouse(true)

    -- open main window on click
    addonButton:SetScript("OnClick", function()
        SL:ToggleWindow()
        -- addonButton:Hide()
    end)

    addonButton:RegisterEvent("AUCTION_HOUSE_CLOSED")
    addonButton:SetScript("OnEvent", function() addonButton:Hide() end)
end

-- https://wowwiki-archive.fandom.com/wiki/Events/Names
local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
buttonPopUpFrame:SetScript("OnEvent", function() private.addonButton() end)

----------------------------------------------------------------------------------
-- AceGUI hacks --

-- hack to hook the escape key for closing the window
function private.SetEscapeHandler(widget, fn)
    widget.origOnKeyDown = widget.frame:GetScript("OnKeyDown")
    widget.frame:SetScript("OnKeyDown", function(self, key)
        widget.frame:SetPropagateKeyboardInput(true)
        if key == "ESCAPE" then
            widget.frame:SetPropagateKeyboardInput(false)
            fn()
        elseif widget.origOnKeyDown then
            widget.origOnKeyDown(self, key)
        end
    end)
    widget.frame:EnableKeyboard(true)
    widget.frame:SetPropagateKeyboardInput(true)
end

function private.GetFromDb(grp, key, ...)
    if not key then return SL.db.profile[grp] end
    return SL.db.profile[grp][key]
end

function private.lpad(str, len, char) return string.rep(char, len) .. str end

function private.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function private.startsWith(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function private.tableToString(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result .. "[\"" .. k .. "\"]" .. "="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result .. private.tableToString(v)
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        else
            result = result .. "\"" .. v .. "\""
        end
        result = result .. ","
    end
    -- Remove leading commas from the result
    if result ~= "{" then result = result:sub(1, result:len() - 1) end
    return result .. "}"
end

function private.ProcessTSMGroup(group, includeSubgroups)
    local items = {}
    SL.TSM.GetGroupItems(group, includeSubgroups, items)
    return private.ProcessItems(items)
end

function private.ProcessItems(items)
    SL.Debug.Log("Items: " .. private.tableToString(items))

    local searchStrings = {}
    local count = 1
    for _, itemString in pairs(items) do
        local itemName = type(itemString) == "string" and
                             SL.TSM.GetItemName(itemString)
        SL.Debug.Log("itemString: " .. itemString)
        if (itemName == nil) then
            SL.Debug.Log("skipped itemString: " .. itemString)
        elseif (string.match(itemString, "::")) then
            local itemLink = type(itemString) == "string" and
                                 SL.TSM.GetItemLink(itemString)
            
                                 SL.Debug.Log("itemLink: " .. itemLink)                     
            local _, _, _, iLevel, _, _, _, _ = C_Item.GetItemInfo(itemLink);
            local searchTerm = {searchString = itemName, minItemLevel = iLevel, maxItemLevel = iLevel, isExact = true}
            local searchString = Auctionator.API.v1.ConvertToSearchString(
                                     addonName, searchTerm)
            SL.Debug.Log("searchString: " .. searchString)
            searchStrings[count] = searchString
            count = count + 1
        else
            local searchTerm = {searchString = itemName, isExact = true}
            local searchString = Auctionator.API.v1.ConvertToSearchString(
                                     addonName, searchTerm)
            SL.Debug.Log("searchString: " .. searchString)
            searchStrings[count] = searchString
            count = count + 1
        end
    end
    local slName = SL.slName:GetText()
    if (slName == nil or slName == "") then
        slName = private.availableTsmGroups[private.GetFromDb("settings",
        "tsmDropdown")]
    end
    Auctionator.API.v1.CreateShoppingList(addonName, slName,
                                          searchStrings)
    return true
end
