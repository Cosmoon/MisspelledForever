local _, ns = ...
local UI = ns.UI
local label, background, button = UI.Label, UI.Background, UI.Button
local tip, checkbox, editbox = UI.Tooltip, UI.Checkbox, UI.EditBox
local ICON = UI.ICON

local function buildOptions(parent)
	parent.controls = {}
	local function add(control) parent.controls[#parent.controls + 1] = control; return control end
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(45, 45); icon:SetPoint("TOPLEFT", 16, -12); icon:SetTexture(ICON)
	label(parent, "MisspelledForever", 72, -15, "GameFontNormalLarge")
	label(parent, "Your words. A little more confidence.", 72, -39, "GameFontHighlightSmall")
	local pages, tabs = {}, {}
	for i, name in ipairs({ "General", "Chat channels", "Personal words", "Languages" }) do
		local page = CreateFrame("Frame", nil, parent)
		page:SetPoint("TOPLEFT", 0, -102); page:SetPoint("BOTTOMRIGHT", 0, 0)
		page:Hide(); pages[i] = page
		local b = button(parent, name, 120, 26, function()
			for j, p in ipairs(pages) do
				p:SetShown(i == j)
				if i == j then tabs[j]:Disable() else tabs[j]:Enable() end
			end
		end)
		b:SetPoint("TOPLEFT", 18 + (i - 1) * 126, -70); tabs[i] = b
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
	general.testResult = label(general, "Choose dictionaries in Languages | works entirely offline", 20, -404, "GameFontHighlightSmall")
	general.testResult:SetWidth(470)

	local languages = pages[4]
	label(languages, "SPELLING LANGUAGES", 20, -2, "GameFontNormal")
	local languageHelp = label(languages, "Enable up to two dictionaries for mixed-language chat.\nA word is accepted if either dictionary recognizes it.", 20, -30, "GameFontHighlightSmall")
	languageHelp:SetWidth(470)
	for i, entry in ipairs(ns.Languages) do
		local code, title = entry[1], entry[2]
		local control = add(checkbox(languages, title, "Check spelling and offer corrections in " .. title .. ".", 16, -74 - (i - 1) * 32,
			function() return ns.db.languages[code] end,
			function(value) ns.SetLanguage(code, value) end))
		local refresh = control.Refresh
		control.Refresh = function(self)
			refresh(self)
			local count = 0
			for _, language in ipairs(ns.Languages) do
				if ns.db.languages[language[1]] then count = count + 1 end
			end
			if ns.db.languages[code] or count < ns.MaxLanguages then self:Enable() else self:Disable() end
		end
	end
	local languageNote = label(languages, "Keep one or two languages enabled.\nTo switch when two are selected, turn one off first.\nNederlands (NL) and (BE) share the OpenTaal dictionary.", 20, -350, "GameFontHighlightSmall")
	languageNote:SetWidth(470)

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
	local footer = label(parent, "1.1.0 - multilingual dictionaries", 175, -563, "GameFontDisableSmall")
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
