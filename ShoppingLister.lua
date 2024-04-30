local addonName = "ShoppingLister"
local addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), addonName, "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName);

local defaults = {
	profile = {
		debug = false, -- for addon debugging
		stripempty = true,
		trimwhitespace = false,
		windowscale = 1.0,
		shiftenter = false,
		settings = {
			discount = "90",
			priceSource = "DBMarket",
			fallback = "1000"
		},
	}
}

local settings = defaults.profile
local optionsFrame

local private = {
	tsmGroups = {},
	availableTsmGroups = {},
	settings = {
		groups = {},
	},
}

local function chatMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. msg)
end

local function debug(msg)
	if addon.db.profile.debug then
		chatMsg(msg)
	end
end

function addon:GetOptions()
	return {
		type = "group",
		set = function(info, val)
			local s = settings; for i = 2, #info - 1 do s = s[info[i]] end
			s[info[#info]] = val; -- debug(info[#info] .. " set to: " .. tostring(val))
			addon:Update()
		end,
		get = function(info)
			local s = settings; for i = 2, #info - 1 do s = s[info[i]] end
			return s[info[#info]]
		end,
		args = {
			general = {
				type = "group",
				inline = true,
				name = L["general"],
				args = {
					debug = {
						name = L["debug"],
						desc = L["debug_toggle"],
						type = "toggle",
						guiHidden = true,
					},
					config = {
						name = L["config"],
						desc = L["config_toggle"],
						type = "execute",
						guiHidden = true,
						func = function() addon:Config() end,
					},
					show = {
						name = L["show"],
						desc = L["show_toggle"],
						type = "execute",
						guiHidden = true,
						func = function() addon:ToggleWindow() end,
					},
					aheader = {
						name = APPEARANCE_LABEL,
						type = "header",
						cmdHidden = true,
						order = 300,
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
						isPercent = true,
					},
				},
			},
		}
	}
end

function addon:RefreshConfig()
	-- things to do after load or settings are reset
	-- debug("RefreshConfig")
	settings = addon.db.profile
	private.settings = settings

	for k, v in pairs(defaults.profile) do
		if settings[k] == nil then
			settings[k] = table_clone(v)
		end
	end

	settings.loaded = true

	addon:Update()
end

function addon:Update()
	-- things to do when settings changed

	if addon.gui then -- scale the window
		local frame = addon.gui.frame
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

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New("ShoppingListerDB", defaults, true)
	addon:RefreshConfig()

	local options = addon:GetOptions()
	LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(options, addonName)
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, { "shoppinglister" })

	optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName, nil, "general")
	optionsFrame.default = function()
		for k, v in pairs(defaults.profile) do
			settings[k] = table_clone(v)
		end

		addon:RefreshConfig()

		if SettingsPanel:IsShown() then
			addon:Config(); addon:Config()
		end
	end

	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Profiles", addonName, "profiles")

	-- debug("OnInitialize")

	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	self.db.RegisterCallback(self, "OnDatabaseReset", "RefreshConfig")
	addon:RegisterChatCommand('sl', 'HandleChatCommand')
	addon:RegisterChatCommand('slist', 'HandleChatCommand')
	addon:RegisterChatCommand('shoppinglister', 'HandleChatCommand')

	private.PrepareTsmGroups()
	addon:RefreshConfig()
end

function addon:HandleChatCommand(input)
	local args = { strsplit(' ', input) }

	for _, arg in ipairs(args) do
		if arg == 'help' then
			DEFAULT_CHAT_FRAME:AddMessage(
				L["default_chat_message"]
			)
			return
		end
	end

	addon:ToggleWindow()
end

function addon:Config()
	if optionsFrame then
		if (SettingsPanel:IsShown()) then
			SettingsPanel:Hide();
		else
			InterfaceOptionsFrame_OpenToCategory(optionsFrame)
		end
	end
end

function addon:OnEnable()
	-- debug("OnEnable")
	addon:Print(format(L["welcome_message"], addonName))
	addon:Update()
end

function addon:ToggleWindow(keystate)
	if keystate == "down" then return end -- ensure keybind doesnt end up in the text box
	-- debug("ToggleWindow")

	if not addon.gui then
		addon:CreateWindow()
	end

	if addon.gui:IsShown() then
		addon.gui:Hide()
	else
		addon.gui:Show()
		addon:Update()
	end
end

function addon:CreateWindow()
	if addon.gui then
		return
	end

	-- Create main window.
	local frame = AceGUI:Create("Frame")
	frame.frame:SetFrameStrata("MEDIUM")
	frame.frame:Raise()
	frame.content:SetFrameStrata("MEDIUM")
	frame.content:Raise()
	frame:Hide()
	addon.gui = frame
	frame:SetTitle(addonName)
	frame:SetCallback("OnClose", OnClose)
	frame:SetLayout("Fill")
	frame.frame:SetClampedToScreen(true)
	settings.pos = settings.pos or {}
	frame:SetStatusTable(settings.pos)
	addon.minwidth = 800
	addon.minheight = 200
	frame:SetWidth(addon.minwidth)
	frame:SetHeight(addon.minheight)
	frame:SetAutoAdjustHeight(true)
	private.SetEscapeHandler(frame, function() addon:ToggleWindow() end)

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
	addon.tsmDropdown = tsmDropdown
	tsmDropdown:SetMultiselect(false)
	tsmDropdown:SetLabel(L["tsm_groups_label"])
	tsmDropdown:SetRelativeWidth(0.5)
	tsmDropdown:SetCallback("OnEnter", private.UpdateValues)
	tsmDropdown:SetCallback("OnValueChanged", function(widget, event, key)
		settings.settings.tsmDropdown = key
		private.UpdateValues()
	end)
	private.UpdateValues()

	-- Create tsm sub group checkbox
	local tsmSubgroups = AceGUI:Create("CheckBox")
	addon.tsmSubgroups = tsmSubgroups
	tsmGroup:AddChild(tsmSubgroups)
	tsmSubgroups:SetType("checkbox")
	tsmSubgroups:SetLabel(L["tsm_checkbox_label"])
	tsmSubgroups:SetValue(true)

	-- Shopping list name
	local slGroup = private.CreateGroup("List", dropdownGroup)
	slGroup:SetFullWidth(false)
	slGroup:SetRelativeWidth(0.5)
	local slName = AceGUI:Create("EditBox")
	addon.slName = slName
	slGroup:AddChild(slName)
	slName:SetLabel(L["sl_name_label"])
	slName:SetRelativeWidth(0.5)
	slName:DisableButton(true)

	-- AceGUI fails at enforcing minimum Frame resize for a container, so fix it
	hooksecurefunc(frame, "OnHeightSet", function(widget, height)
		if (widget ~= addon.gui) then return end
		if (height < addon.minheight) then
			frame:SetHeight(addon.minheight)
		end
	end)

	hooksecurefunc(frame, "OnWidthSet", function(widget, width)
		if (widget ~= addon.gui) then return end
		if (width < addon.minwidth) then
			frame:SetWidth(addon.minwidth)
		end
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
		if (addon.TSM.IsLoaded()) then
			addon.tsmDropdown:SetValue("")
		end
		addon.gui:SetStatusText("")
		addon.slName:SetText("")
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
	addon.tsmDropdown:SetValue("")
	settings.settings.tsmDropdown = ""
end

function private.UpdateValues()
	-- debug("UpdateValues")
	local widgetTsmDropdown = addon.tsmDropdown
	if widgetTsmDropdown and not widgetTsmDropdown.open then
		-- debug("Setting tsm groups dropdown")
		widgetTsmDropdown:SetList(private.availableTsmGroups)
	end
end

function private.PrepareTsmGroups()
	-- debug("PrepareTsmGroups()")

	-- price source check --
	local tsmGroups = addon.TSM.GetGroups() or {}
	-- debug(format("loaded %d tsm groups", private.tablelength(tsmGroups)));
	-- debug("Groups: " .. private.tableToString(tsmGroups))

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

		addon:Print(L["addon_disabled"]);
		addon:Disable();
		return
	end

	private.tsmGroups = tsmGroups

	for k, v in pairs(tsmGroups) do
		local parent, group = addon.TSM.SplitGroupPath(v)
		local _, c = v:gsub("`", "")

		if (parent ~= nil) then
			group = private.lpad(addon.TSM.FormatGroupPath(group), c * 4, " ")
		end
		table.insert(private.availableTsmGroups, k, group)
	end
end

function private.Transform()
	local selectedGroup = private.tsmGroups[private.GetFromDb("settings", "tsmDropdown")]
	local subgroups = addon.tsmSubgroups:GetValue()

	-- debug("Transforming: " .. selectedGroup .. " including subgroups: " .. tostring(subgroups))
	if private.ProcessTSMGroup(selectedGroup, subgroups) then
		addon.gui:SetStatusText(L["status_text"])
		return true
	end

	return false
end

-- easy button system
function private.addonButton()
	local addonButton = CreateFrame("Button", "Shopping Lister", UIParent, "UIPanelButtonTemplate")
	addonButton:SetFrameStrata("HIGH")
	addonButton:SetSize(120, 22) -- width, height
	addonButton:SetText("Shopping Lister")
	-- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
	addonButton:SetPoint("TOPLEFT", "AuctionHouseFrame", "TOPLEFT", 80, 0)

	-- make moveable
	addonButton:SetMovable(true)
	addonButton:EnableMouse(true)
	addonButton:RegisterForDrag("LeftButton")
	addonButton:SetScript("OnDragStart", function(self, button)
		self:StartMoving()
		-- print("OnDragStart", button)
	end)
	addonButton:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- print("OnDragStop")
	end)

	-- open main window on click
	addonButton:SetScript("OnClick", function()
		addon:ToggleWindow()
		-- addonButton:Hide()
	end)

	addonButton:RegisterEvent("AUCTION_HOUSE_CLOSED")
	addonButton:SetScript("OnEvent", function()
		addonButton:Hide()
	end)
end

-- https://wowwiki-archive.fandom.com/wiki/Events/Names
local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
buttonPopUpFrame:SetScript("OnEvent", function()
	private.addonButton()
end)

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
	if not key then
		return addon.db.profile[grp]
	end
	return addon.db.profile[grp][key]
end

function private.lpad(str, len, char)
	return string.rep(char, len) .. str
end

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
	if result ~= "{" then
		result = result:sub(1, result:len() - 1)
	end
	return result .. "}"
end

function private.ProcessTSMGroup(group, includeSubgroups)
	local items = {}
	addon.TSM.GetGroupItems(group, includeSubgroups, items)
	return private.ProcessItems(items)
end

function private.ProcessItems(items)
	-- debug("Items: " .. private.tableToString(items))

	local searchStrings = {}
	local count = 1
	for _, itemString in pairs(items) do
		local itemName = type(itemString) == "string" and addon.TSM.GetItemName(itemString)
		-- debug("itemString: " .. itemString)
		-- debug("itemName: " .. itemName)
		if (itemName == nil or string.match(itemString, "::")) then
			-- debug("skipped itemString: " .. itemString)
			-- debug("skipped itemName: " .. itemName)
		else
			local searchTerm = {
				searchString = itemName,
				isExact = true,
			}
			local searchString = Auctionator.API.v1.ConvertToSearchString(addonName, searchTerm)
			searchStrings[count] = searchString
			count = count + 1
		end
	end
	Auctionator.API.v1.CreateShoppingList(addonName, addon.slName:GetText(), searchStrings)
	return true
end
