local _, ns = ...
local UI = {}
ns.UI = UI
local ACCENT = { 0.32, 0.78, 0.72 }
local ICON = "Interface\\AddOns\\MisspelledForever\\Assets\\MisspelledForeverLogo.tga"

local function label(parent, text, x, y, template)
	local value = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	value:SetPoint("TOPLEFT", x, y)
	value:SetText(text)
	value:SetJustifyH("LEFT")
	return value
end

local function background(frame)
	frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	frame:SetBackdropColor(0.035, 0.055, 0.07, 0.97)
	frame:SetBackdropBorderColor(0.18, 0.34, 0.36, 1)
end

local function button(parent, text, width, height, action)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height or 24)
	b:SetText(text)
	b:SetScript("OnClick", action)
	return b
end

local function tip(frame, heading, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(heading)
		GameTooltip:AddLine(text, 0.85, 0.9, 0.9, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function checkbox(parent, heading, text, x, y, get, set)
	local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	b:SetPoint("TOPLEFT", x, y)
	b:SetSize(26, 26)
	b.text = label(b, heading, 29, -5)
	b.text:SetWidth(430)
	b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	b.Refresh = function(self) self:SetChecked(get()) end
	b:Refresh()
	tip(b, heading, text)
	return b
end

local function editbox(parent, width, height, multiline)
	local b = CreateFrame("EditBox", nil, parent, multiline and "BackdropTemplate" or "InputBoxTemplate")
	b:SetSize(width, height)
	b:SetAutoFocus(false)
	b:SetFontObject("ChatFontNormal")
	if multiline then
		background(b)
		b:SetMultiLine(true)
		b:SetTextInsets(10, 10, 10, 10)
	end
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return b
end

function UI:CreateCorrectionPanel()
	local panel = CreateFrame("Frame", "MisspelledForeverCorrectionPanel", UIParent, "BackdropTemplate")
	panel:SetSize(440, 64)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	background(panel)
	panel:Hide()
	panel.title = label(panel, "MisspelledForever", 12, -10, "GameFontNormalSmall")
	panel.title:SetTextColor(unpack(ACCENT))
	panel.status = label(panel, "", 12, -36, "GameFontDisableSmall")
	local settings = button(panel, "...", 25, 22, function() ns.OpenSettings() end)
	settings:SetPoint("TOPRIGHT", -10, -8)
	tip(settings, "Settings", "Open spelling options and your personal dictionary.")
	local close = button(panel, "x", 25, 22, function() ns.DismissPanel() end)
	close:SetPoint("TOPRIGHT", -40, -8)
	tip(close, "Close suggestions", "Click an colored word to open suggestions again.")
	panel.suggestions = {}
	for i = 1, 8 do
		local b = button(panel, "", 197, 22, function(self) ns.ApplyCorrection(self.word) end)
		b:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 207, -57 - math.floor((i - 1) / 2) * 26)
		b:Hide()
		panel.suggestions[i] = b
	end
	panel.learn = button(panel, "Learn word", 110, 23, function() ns.LearnSelected() end)
	panel.ignore = button(panel, "Ignore for session", 144, 23, function() ns.IgnoreSelected() end)
	panel.learn:SetPoint("BOTTOMLEFT", 12, 10)
	panel.ignore:SetPoint("BOTTOMLEFT", 130, 10)
	panel.learn:Hide(); panel.ignore:Hide()
	self.panel = panel
end

function UI:OpenSuggestions(editBox, issue)
	local panel = self.panel
	panel:ClearAllPoints()
	panel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 8)
	panel:SetScale(ns.db.panelScale)
	panel.title:SetText(issue.word)
	panel.title:SetTextColor(unpack(ns.db.highlightColor))
	for _, b in ipairs(panel.suggestions) do b:Hide() end
	panel:Show()
end

function UI:ShowSuggestions(word, suggestions, pending)
	local panel = self.panel
	local rows = pending and 1 or math.max(1, math.ceil(#suggestions / 2))
	panel:SetHeight(97 + rows * 26)
	panel.status:SetText(pending and ("Finding corrections for " .. word .. "...")
		or (#suggestions == 0 and "No close match. You can learn or ignore this word." or "Click a correction to replace only this word."))
	for i, b in ipairs(panel.suggestions) do
		if suggestions[i] and not pending then
			b.word = suggestions[i]
			b:SetText(suggestions[i]); b:Show()
		else b:Hide() end
	end
	panel.learn:Show(); panel.ignore:Show()
	panel:Show()
end

local function buildOptions(parent)
	parent.controls = {}
	local function add(control) parent.controls[#parent.controls + 1] = control; return control end
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(45, 45); icon:SetPoint("TOPLEFT", 16, -12); icon:SetTexture(ICON)
	label(parent, "MisspelledForever", 72, -15, "GameFontNormalLarge")
	label(parent, "Your words. A little more confidence.", 72, -39, "GameFontHighlightSmall")
	local pages, tabs = {}, {}
	for i, name in ipairs({ "General", "Chat channels", "Personal words" }) do
		local page = CreateFrame("Frame", nil, parent)
		page:SetPoint("TOPLEFT", 0, -102); page:SetPoint("BOTTOMRIGHT", 0, 0)
		page:Hide(); pages[i] = page
		local b = button(parent, name, 156, 26, function()
			for j, p in ipairs(pages) do
				p:SetShown(i == j)
				if i == j then tabs[j]:Disable() else tabs[j]:Enable() end
			end
		end)
		b:SetPoint("TOPLEFT", 18 + (i - 1) * 162, -70); tabs[i] = b
	end
	pages[1]:Show(); tabs[1]:Disable()
	local general = pages[1]
	label(general, "SPELLING", 20, -2, "GameFontNormal")
	local function option(page, key, title, text, x, y)
		return add(checkbox(page, title, text, x, y,
			function() return ns.db[key] end,
			function(value) ns.SetOption(key, value) end))
	end
	option(general, "enabled", "Enable spelling checks", "Checks outgoing chat as you type. Corrections are applied only when you choose one.", 16, -25)
	option(general, "showHighlights", "Color possible spelling mistakes", "Colors completed words in the chat box. Click a colored word for suggestions. Suggestions never open automatically.", 16, -55)
	option(general, "wowVocabulary", "Recognize WoW terms and chat shorthand", "Accepts common spells, places, classes, and terms such as LFG, aggro, and hearthstone.", 16, -85)
	option(general, "ignoreUppercase", "Ignore words written in ALL CAPS", "Useful for abbreviations. Disable this if you want uppercase misspellings checked too.", 16, -115)
	label(general, "MINIMAP", 20, -158, "GameFontNormal")
	option(general, "showMinimap", "Show the minimap button", "Left-click opens settings. Right-click toggles spelling checks. Drag to move it. /mf always opens settings, even when this button is hidden.", 16, -180)
	label(general, "SUGGESTIONS", 20, -222, "GameFontNormal")
	local countLabel = label(general, "", 20, -251)
	add({ Refresh = function() countLabel:SetText("Suggestions: " .. ns.db.maxSuggestions) end })
	local fewer = button(general, "-", 30, 22, function() ns.SetOption("maxSuggestions", math.max(2, ns.db.maxSuggestions - 1)) end)
	fewer:SetPoint("TOPLEFT", 190, -245)
	local more = button(general, "+", 30, 22, function() ns.SetOption("maxSuggestions", math.min(8, ns.db.maxSuggestions + 1)) end)
	more:SetPoint("TOPLEFT", 226, -245)
	local scaleLabel = label(general, "", 20, -283)
	add({ Refresh = function() scaleLabel:SetText("Panel size: " .. math.floor(ns.db.panelScale * 100 + 0.5) .. "%") end })
	local smaller = button(general, "-", 30, 22, function() ns.SetOption("panelScale", math.max(0.8, ns.db.panelScale - 0.1)) end)
	smaller:SetPoint("TOPLEFT", 190, -277)
	local larger = button(general, "+", 30, 22, function() ns.SetOption("panelScale", math.min(1.4, ns.db.panelScale + 0.1)) end)
	larger:SetPoint("TOPLEFT", 226, -277)
	label(general, "Word color:", 20, -315)
	for i, preset in ipairs({ { "Coral", {1, 0.42, 0.34} }, { "Gold", {1, 0.78, 0.25} }, { "Sky", {0.35, 0.75, 1} } }) do
		local b = button(general, preset[1], 77, 22, function() ns.SetOption("highlightColor", preset[2]) end)
		b:SetPoint("TOPLEFT", 190 + (i - 1) * 83, -309)
		b:GetFontString():SetTextColor(unpack(preset[2]))
	end
	local sample = editbox(general, 345, 26)
	sample:SetPoint("TOPLEFT", 26, -367); sample:SetText("I misspeld that mesage")
	local test = button(general, "Check", 95, 25, function()
		local issues = ns.Engine:Check(sample:GetText(), ns.db, {})
		local words = {}
		for _, issue in ipairs(issues) do words[#words + 1] = issue.word end
		general.testResult:SetText(#words == 0 and "All words recognized." or ("Check: " .. table.concat(words, ", ")))
		sample:ClearFocus()
	end)
	test:SetPoint("TOPLEFT", 392, -364)
	label(general, "Try a sentence", 20, -343, "GameFontNormal")
	general.testResult = label(general, "English (US) dictionary â€¢ works entirely offline", 20, -404, "GameFontHighlightSmall")
	general.testResult:SetWidth(470)

	local channels = pages[2]
	label(channels, "CHECK THESE CHANNELS", 20, -2, "GameFontNormal")
	local channelNames = {
		{"SAY", "Say"}, {"YELL", "Yell"}, {"WHISPER", "Whispers"}, {"GUILD", "Guild"},
		{"OFFICER", "Officer"}, {"PARTY", "Party"}, {"RAID", "Raid"},
		{"INSTANCE_CHAT", "Battleground / instance"}, {"CHANNEL", "General, Trade, and other channels"},
		{"EMOTE", "Emotes"},
	}
	for i, entry in ipairs(channelNames) do
		add(checkbox(channels, entry[2], "Enable spelling checks in " .. entry[2]:lower() .. ".", 16, -22 - (i - 1) * 31,
			function() return ns.db.channels[entry[1]] end,
			function(value) ns.db.channels[entry[1]] = value; ns.OptionsChanged() end))
	end
	local explanation = label(channels, "The checker reads only the message you are typing.\nIt never changes or sends a message on its own.", 20, -352, "GameFontHighlightSmall")
	explanation:SetWidth(470)

	local personal = pages[3]
	label(personal, "YOUR DICTIONARY", 20, -2, "GameFontNormal")
	local help = label(personal, "Add names, guild terms, or your own shorthand. One word per line.\nSaving replaces your personal list; session ignores stay temporary.", 20, -28, "GameFontHighlightSmall")
	help:SetWidth(470)
	local scroll = CreateFrame("ScrollFrame", nil, personal, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 22, -72); scroll:SetSize(439, 250)
	local words = editbox(scroll, 430, 250, true)
	words:SetMaxLetters(20000)
	scroll:SetScrollChild(words)
	words:SetScript("OnTextChanged", function(self)
		local lines = 1
		for line in (self:GetText() .. "\n"):gmatch("(.-)\n") do
			lines = lines + math.max(1, math.ceil(#line / 48))
		end
		self:SetHeight(math.max(250, lines * 18 + 20))
		scroll:UpdateScrollChildRect()
	end)
	words:SetScript("OnCursorChanged", function(_, _, y, _, height)
		local current = scroll:GetVerticalScroll()
		local cursorTop = -y
		if cursorTop < current then scroll:SetVerticalScroll(math.max(0, cursorTop))
		elseif cursorTop + height > current + scroll:GetHeight() then
			scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), cursorTop + height - scroll:GetHeight()))
		end
	end)
	personal.words = words
	personal.note = label(personal, "", 20, -363, "GameFontHighlightSmall")
	personal.note:SetWidth(460)
	local save = button(personal, "Save word list", 140, 26, function()
		local saved, err = ns.SavePersonalWords(words:GetText())
		personal.note:SetText(err or ("Saved " .. saved .. " personal words."))
		words:ClearFocus()
	end)
	save:SetPoint("TOPLEFT", 20, -330)
	local clear = button(personal, "Clear session ignores", 175, 26, function()
		ns.ClearIgnores(); personal.note:SetText("Session ignores cleared.")
	end)
	clear:SetPoint("TOPLEFT", 170, -330)
	local reset = button(parent, "Reset options", 125, 24, function() ns.ResetOptions() end)
	reset:SetPoint("BOTTOMLEFT", 20, 18)
	tip(reset, "Reset options", "Restores display and channel settings. Keeps your personal dictionary.")
	local footer = label(parent, "1.0.0 - independent rebuild", 175, -563, "GameFontDisableSmall")
	parent.Refresh = function(self)
		for _, control in ipairs(self.controls) do control:Refresh() end
		local list = {}
		for word in pairs(ns.db.personalWords) do list[#list + 1] = word end
		table.sort(list)
		if not words:HasFocus() then words:SetText(table.concat(list, "\n")) end
	end
	parent:SetScript("OnShow", function(self) self:Refresh() end)
	parent:Refresh()
end

function UI:CreateOptions()
	local window = CreateFrame("Frame", "MisspelledForeverOptions", UIParent, "BackdropTemplate")
	window:SetSize(535, 610); window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG"); window:SetClampedToScreen(true)
	window:SetMovable(true); window:EnableMouse(true); window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	background(window); window:Hide()
	buildOptions(window)
	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -3, -3)
	table.insert(UISpecialFrames, "MisspelledForeverOptions")
	self.options = window

	-- A matching panel is also available through the game's AddOns settings.
	local canvas = CreateFrame("Frame", nil, UIParent)
	canvas.name = "MisspelledForever"; canvas:SetSize(535, 610); canvas:Hide()
	buildOptions(canvas)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(canvas, canvas.name)
		Settings.RegisterAddOnCategory(category)
		self.category = category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(canvas)
	end
	self.canvas = canvas
end

function UI:RefreshOptions()
	if self.options then self.options:Refresh(); self.canvas:Refresh() end
end

function UI:UpdateMinimap()
	if not self.minimap then return end
	local angle = math.rad(ns.db.minimapAngle)
	local halfWidth, halfHeight = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
	local x, y = math.cos(angle), math.sin(angle)
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local round = {
		ROUND = {true, true, true, true}, SQUARE = {false, false, false, false},
		["CORNER-TOPLEFT"] = {false, false, false, true},
		["CORNER-TOPRIGHT"] = {false, false, true, false},
		["CORNER-BOTTOMLEFT"] = {false, true, false, false},
		["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
		["SIDE-LEFT"] = {false, true, false, true},
		["SIDE-RIGHT"] = {true, false, true, false},
		["SIDE-TOP"] = {false, false, true, true},
		["SIDE-BOTTOM"] = {true, true, false, false},
		["TRICORNER-TOPLEFT"] = {false, true, true, true},
		["TRICORNER-TOPRIGHT"] = {true, false, true, true},
		["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
		["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
	}
	local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
	if not (round[shape] or round.ROUND)[quadrant] then
		local divisor = math.max(math.abs(x), math.abs(y))
		x, y = x / divisor, y / divisor
	end
	self.minimap:ClearAllPoints()
	self.minimap:SetPoint("CENTER", Minimap, "CENTER", x * (halfWidth + 7), y * (halfHeight + 7))
	self.minimap:SetShown(ns.db.showMinimap)
end

function UI:CreateMinimap()
	local b = CreateFrame("Button", "MisspelledForeverMinimapButton", Minimap)
	b:SetSize(32, 32); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON); icon:SetSize(22, 22); icon:SetPoint("CENTER")
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54); border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then ns.SetOption("enabled", not ns.db.enabled)
		else ns.OpenSettings() end
	end)
	b:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local cx, cy = Minimap:GetCenter()
			local mx, my = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.db.minimapAngle = math.deg(math.atan2(my / scale - cy, mx / scale - cx))
			UI:UpdateMinimap()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("MisspelledForever")
		GameTooltip:AddLine(ns.db.enabled and "Spelling checks enabled" or "Spelling checks paused", unpack(ACCENT))
		GameTooltip:AddLine("Left-click: settings\nRight-click: enable / pause\nDrag: move button", 0.9, 0.9, 0.9)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.minimap = b
	Minimap:HookScript("OnSizeChanged", function() UI:UpdateMinimap() end)
	self:UpdateMinimap()
end

-- Native edit-box colors. No overlay measuring, resizing, or update polling.
UI.markers = {}

function UI:RawText(box)
	local marker = self.markers[box]
	return ns.Engine.StripHighlights(box:GetText(), marker and marker.prefixes, box:GetCursorPosition())
end

function UI:IsFormatting(box)
	local marker = self.markers[box]
	-- The game can deliver OnTextChanged after SetText has returned. A
	-- call-stack guard alone then treats our own colors as new user input,
	-- strips them, and schedules another highlight indefinitely.
	return marker and (marker.updating or box:GetText() == marker.expectedText)
end

local function setDisplay(box, marker, text, cursor)
	if box:GetText() == text then return end
	marker.expectedText = text
	marker.updating = true
	box:SetText(text)
	box:SetCursorPosition(cursor)
	marker.updating = false
end

function UI:ClearMarks(box)
	for editBox, marker in pairs(self.markers) do
		if not box or box == editBox then
			local raw, cursor = self:RawText(editBox)
			setDisplay(editBox, marker, raw, cursor)
			marker.issues, marker.ranges = {}, {}
		end
	end
end

function UI:ShowMarks(box, issues)
	local marker = self.markers[box]
	if not marker then
		marker = { prefixes = {}, issues = {}, ranges = {} }
		self.markers[box] = marker
	end
	local raw, cursor = self:RawText(box)
	marker.text, marker.issues, marker.ranges = raw, issues, issues
	local color = ns.db.highlightColor
	-- The private alpha value distinguishes these tags from ordinary |cff
	-- item-link colors. Visually it is effectively opaque.
	local prefix = string.format("|cfe%02x%02x%02x", math.floor(color[1]*255+0.5),
		math.floor(color[2]*255+0.5), math.floor(color[3]*255+0.5))
	marker.prefixes[prefix] = true
	local result, from, decoratedCursor, extra = {}, 1, cursor, 0
	local maxBytes = box.GetMaxBytes and box:GetMaxBytes() or 0
	for _, issue in ipairs(issues) do
		result[#result+1] = raw:sub(from, issue.first-1)
		local highlighted = ns.db.showHighlights and ns.db.enabled
			and (maxBytes == 0 or #raw + extra + 12 <= maxBytes)
		if highlighted then
			result[#result+1] = prefix .. issue.word .. "|r"
			extra = extra + 12
			if cursor >= issue.first-1 then decoratedCursor = decoratedCursor + 10 end
			if cursor >= issue.last then decoratedCursor = decoratedCursor + 2 end
		else result[#result+1] = issue.word end
		from = issue.last+1
	end
	result[#result+1] = raw:sub(from)
	local decorated = table.concat(result)
	setDisplay(box, marker, decorated, decoratedCursor)
	-- A client may enforce an additional visible/invisible character limit.
	-- Restore the entire original input if display formatting was truncated.
	if box:GetText() ~= decorated then setDisplay(box, marker, raw, cursor) end
end

function UI:IssueAtMouse(box)
	local marker = self.markers[box]
	if not marker then return end
	local raw, cursor = self:RawText(box)
	if marker.text ~= raw then return end
	for _, issue in ipairs(marker.issues) do
		if cursor >= issue.first-1 and cursor <= issue.last then return issue end
	end
end
