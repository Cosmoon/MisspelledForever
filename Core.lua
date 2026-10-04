local ADDON, ns = ...
local Engine, UI = ns.Engine, ns.UI
local driver = CreateFrame("Frame")
local defaults = {
	enabled = true, showHighlights = true, wowVocabulary = true, ignoreUppercase = true,
	showMinimap = true, minimapAngle = 220, maxSuggestions = 6, panelScale = 1,
	minLength = 2, highlightColor = { 1, 0.42, 0.34 }, personalWords = {},
	channels = { SAY = true, YELL = true, WHISPER = true, GUILD = true,
		OFFICER = true, PARTY = true, RAID = true, INSTANCE_CHAT = true,
		CHANNEL = true, EMOTE = false },
}
local state = { hooked = {}, ignored = {}, cache = {}, cacheOrder = {} }

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end

local function restoreDefaults(db, model)
	for key, value in pairs(model) do
		if type(db[key]) ~= type(value) then db[key] = copy(value)
		elseif type(value) == "table" then restoreDefaults(db[key], value) end
	end
end

local function printMessage(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff52c7b8MisspelledForever:|r " .. text)
end

local function channelEnabled(box)
	local channel = box:GetAttribute("chatType") or "SAY"
	if channel == "PARTY_LEADER" then channel = "PARTY"
	elseif channel == "RAID_LEADER" or channel == "RAID_WARNING" then channel = "RAID"
	elseif channel == "INSTANCE_CHAT_LEADER" then channel = "INSTANCE_CHAT"
	elseif channel == "BN_WHISPER" then channel = "WHISPER" end
	return ns.db.channels[channel] == true
end

local function invalidateCache()
	state.cache, state.cacheOrder, state.job = {}, {}, nil
end

local function cacheResult(word, value)
	if not state.cache[word] then state.cacheOrder[#state.cacheOrder + 1] = word end
	state.cache[word] = value
	if #state.cacheOrder > 100 then
		state.cache[table.remove(state.cacheOrder, 1)] = nil
	end
end

function ns.OpenSettings()
	UI.panel:Hide()
	state.job = nil
	UI.options:Show(); UI.options:Raise()
end

function ns.DismissPanel()
	state.job, state.selected = nil, nil
	UI.panel:Hide()
end

function ns.OptionsChanged()
	invalidateCache()
	UI:RefreshOptions(); UI:UpdateMinimap()
	UI.panel:Hide()
	UI:ClearMarks()
	state.pendingAt = GetTime() + 0.05
end

function ns.SetOption(key, value)
	ns.db[key] = value
	ns.OptionsChanged()
end

function ns.ResetOptions()
	local personal = ns.db.personalWords
	for key, value in pairs(defaults) do ns.db[key] = copy(value) end
	ns.db.personalWords = personal
	ns.OptionsChanged()
end

local function validPersonalWord(word)
	return #word >= 2 and #word <= 28 and word:match("^[a-z]+'?[%a]*$") ~= nil
end

function ns.SavePersonalWords(text)
	local words, count = {}, 0
	for line in text:gmatch("[^\r\n]+") do
		local word = Engine.Normalize(line:match("^%s*(.-)%s*$"))
		if word ~= "" then
			if not validPersonalWord(word) then
				return nil, "Use one English word per line (2â€“28 letters; apostrophes allowed)."
			end
			if not words[word] then words[word] = true; count = count + 1 end
			if count > 800 then return nil, "The personal dictionary supports up to 800 words." end
		end
	end
	ns.db.personalWords, Engine.personal = words, words
	ns.OptionsChanged()
	return count
end

function ns.ClearIgnores()
	state.ignored = {}
	ns.OptionsChanged()
end

local function selectionIsCurrent()
	return state.box and state.box:IsShown() and state.selected
		and UI:RawText(state.box) == state.snapshot and ns.db.enabled and channelEnabled(state.box)
end

function ns.LearnSelected()
	if not selectionIsCurrent() then return end
	local word = state.selected.normalized
	local count = 0
	for _ in pairs(ns.db.personalWords) do count = count + 1 end
	if count >= 800 then printMessage("Your personal dictionary is full. Edit it in /mf."); return end
	if validPersonalWord(word) then
		ns.db.personalWords[word] = true
		ns.OptionsChanged()
		state.box:SetFocus()
	end
end

function ns.IgnoreSelected()
	if not selectionIsCurrent() then return end
	state.ignored[state.selected.normalized] = true
	state.job = nil
	UI.panel:Hide()
	state.box:SetFocus()
	state.pendingAt = GetTime()
end

function ns.ApplyCorrection(word)
	if not selectionIsCurrent() then return end
	local box = state.box
	local value, cursor = Engine.Replace(UI:RawText(box), state.selected, word, select(2, UI:RawText(box)))
	if not value then return end
	-- Never silently truncate a replacement at the edit box's byte limit.
	local maxBytes = box.GetMaxBytes and box:GetMaxBytes() or 0
	local maxLetters = box.GetMaxLetters and box:GetMaxLetters() or 0
	local letters = strlenutf8 and strlenutf8(value) or #value
	if (maxBytes > 0 and #value > maxBytes) or (maxLetters > 0 and letters > maxLetters) then
		printMessage("That correction would exceed the chat length limit.")
		return
	end
	state.job, state.selected = nil, nil
	UI.panel:Hide()
	box:SetText(value); box:SetCursorPosition(cursor); box:SetFocus()
	state.pendingAt = GetTime() + 0.05
end

function ns.SelectIssue(issue)
	if not state.box or UI:RawText(state.box) ~= state.snapshot then return end
	state.selected = issue
	UI:OpenSuggestions(state.box, issue)
	local cached = state.cache[issue.normalized]
	if cached then UI:ShowSuggestions(issue.word, cached, false); return end
	UI:ShowSuggestions(issue.word, {}, true)
	local job = { word = issue.normalized, snapshot = state.snapshot, issue = issue }
	job.thread = coroutine.create(function()
		return Engine:Suggest(job.word, ns.db, function() coroutine.yield() end)
	end)
	state.job = job
end

local function check(box, force)
	state.job, state.selected = nil, nil
	if not box or not box:IsShown() or not ns.db.enabled or not channelEnabled(box) then
		UI.panel:Hide(); UI:ClearMarks(box); return
	end
	local text = UI:RawText(box)
	local issues = Engine:Check(text, ns.db, state.ignored)
	local _, cursor = UI:RawText(box)
	if not force then
		-- Wait for a word boundary before flagging the word still being typed.
		for i = #issues, 1, -1 do
			if issues[i].last == #text and cursor >= #text then table.remove(issues, i) end
		end
	end
	state.box, state.snapshot, state.issues = box, text, issues
	UI.panel:Hide()
	UI:ShowMarks(box, issues)
end

local function wireBox(box)
	if not box or state.hooked[box] then return end
	state.hooked[box] = true
	box:HookScript("OnTextChanged", function(self)
		if UI:IsFormatting(self) then return end
		UI:ClearMarks(self)
		state.box, state.pendingAt, state.force = self, GetTime() + 0.3, false
		state.job, state.selected = nil, nil
		UI.panel:Hide()
	end)
	box:HookScript("OnShow", function(self)
		state.box, state.pendingAt = self, GetTime() + 0.1
	end)
	box:HookScript("OnHide", function(self)
		if state.box == self then
			state.job, state.selected, state.pendingAt, state.force = nil, nil, nil, false
			UI.panel:Hide()
			UI:ClearMarks(self)
		end
	end)
	box:HookScript("OnMouseDown", function(self)
		local x, y = GetCursorPosition()
		self.mfMouseDown = {x, y}
	end)
	box:HookScript("OnMouseUp", function(self, mouse)
		if mouse ~= "LeftButton" and mouse ~= "RightButton" then return end
		local x, y = GetCursorPosition()
		local down = self.mfMouseDown
		self.mfMouseDown = nil
		-- Dragging to select text should retain the normal edit-box behavior.
		if down and (math.abs(x - down[1]) > 3 or math.abs(y - down[2]) > 3) then
			ns.DismissPanel(); return
		end
		-- Resolve the word after the native edit box finishes moving its caret.
		state.clickBox, state.clickButton, state.clickAt = self, mouse, GetTime() + 0.01
		state.pendingAt = nil
	end)
	box:HookScript("OnAttributeChanged", function(self, attribute)
		if attribute == "chatType" then
			state.box, state.pendingAt = self, GetTime() + 0.05
		end
	end)
end

local function wireAllBoxes()
	wireBox(_G.ChatFrameEditBox)
	for i = 1, NUM_CHAT_WINDOWS or 10 do wireBox(_G["ChatFrame" .. i .. "EditBox"]) end
end

local function rememberNames()
	local function remember(unit)
		local name = UnitName(unit)
		-- Restricted unit names cannot be compared, normalized, or used as keys.
		if issecretvalue and issecretvalue(name) then return end
		if name and name ~= "" then Engine.names[Engine.Normalize(name)] = true end
	end
	remember("player"); remember("target")
	for i = 1, 4 do remember("party" .. i) end
	for i = 1, 40 do remember("raid" .. i) end
end

driver:SetScript("OnUpdate", function()
	if not ns.db then return end
	if state.clickAt and GetTime() >= state.clickAt then
		local box, mouse = state.clickBox, state.clickButton
		state.clickBox, state.clickButton, state.clickAt = nil, nil, nil
		state.box = box
		check(box, mouse == "RightButton")
		local issue = box:IsShown() and UI:IssueAtMouse(box)
		if issue and (ns.db.showHighlights or mouse == "RightButton") then
			ns.SelectIssue(issue)
		else ns.DismissPanel() end
	end
	if state.pendingAt and GetTime() >= state.pendingAt then
		local force = state.force
		state.pendingAt, state.force = nil, false
		check(state.box, force)
	end
	local job = state.job
	if job then
		if not selectionIsCurrent() or state.selected ~= job.issue then state.job = nil; return end
		local start = debugprofilestop and debugprofilestop() or 0
		-- Suggestions run in short slices so chat stays responsive.
		for _ = 1, debugprofilestop and 20 or 4 do
			local ok, result = coroutine.resume(job.thread)
			if not ok then
				state.job = nil
				UI:ShowSuggestions(job.issue.word, {}, false)
				geterrorhandler()("MisspelledForever suggestion error: " .. tostring(result))
				break
			end
			if coroutine.status(job.thread) == "dead" then
				state.job = nil
				cacheResult(job.word, result)
				UI:ShowSuggestions(job.issue.word, result, false)
				break
			end
			if debugprofilestop and debugprofilestop() - start >= 2 then break end
		end
	end
end)

driver:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		MisspelledForeverDB = type(MisspelledForeverDB) == "table" and MisspelledForeverDB or {}
		ns.db = MisspelledForeverDB
		restoreDefaults(ns.db, defaults)
		ns.db.autoPanel, ns.db.showUnderlines = nil, nil -- Retire popup/underline settings.
		ns.db.maxSuggestions = math.floor(math.max(2, math.min(8, ns.db.maxSuggestions)))
		ns.db.panelScale = math.max(0.8, math.min(1.4, ns.db.panelScale))
		ns.db.minLength = math.max(2, math.min(5, ns.db.minLength))
		for i = 1, 3 do ns.db.highlightColor[i] = math.max(0, math.min(1, ns.db.highlightColor[i])) end
		for word, value in pairs(ns.db.personalWords) do
			if type(word) ~= "string" or not validPersonalWord(word) or value ~= true then ns.db.personalWords[word] = nil end
		end
		Engine:Initialize(ns.db.personalWords)
		UI:CreateCorrectionPanel(); UI:CreateOptions(); UI:CreateMinimap()
		wireAllBoxes()
		-- Clean display-only colors before Blizzard parses, sends, or saves
		-- history. Item links and user formatting retain their original tags.
		if ChatEdit_SendText then
			local originalSend = ChatEdit_SendText
			ChatEdit_SendText = function(box, ...)
				UI:ClearMarks(box)
				return originalSend(box, ...)
			end
		end
		if ChatEdit_ActivateChat then hooksecurefunc("ChatEdit_ActivateChat", wireBox) end
		if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", wireAllBoxes) end
		SLASH_MISSPELLEDFOREVER1, SLASH_MISSPELLEDFOREVER2 = "/mf", "/misspelledforever"
		SlashCmdList.MISSPELLEDFOREVER = function(message)
			local command, argument = message:match("^%s*(%S*)%s*(.-)%s*$")
			command = command:lower()
			if command == "on" or command == "off" then
				ns.SetOption("enabled", command == "on")
				printMessage(command == "on" and "Spelling checks enabled." or "Spelling checks paused.")
			elseif command == "minimap" then
				ns.SetOption("showMinimap", not ns.db.showMinimap)
				printMessage(ns.db.showMinimap and "Minimap button shown." or "Minimap button hidden. Use /mf for settings.")
			elseif command == "add" then
				local word = Engine.Normalize(argument)
				local count = 0
				for _ in pairs(ns.db.personalWords) do count = count + 1 end
				if validPersonalWord(word) and count < 800 then
					ns.db.personalWords[word] = true; ns.OptionsChanged(); printMessage("Learned " .. word .. ".")
				else printMessage("Use /mf add <word> (2â€“28 English letters), or edit your personal list in /mf.") end
			elseif command == "help" then
				printMessage("/mf settings â€¢ /mf on|off â€¢ /mf minimap â€¢ /mf add <word>. Click an colored word for corrections.")
			elseif command == "debug" then
				local hooked = 0
				for _ in pairs(state.hooked) do hooked = hooked + 1 end
				local marker = state.box and UI.markers[state.box]
				printMessage("Color build 1; checking=" .. tostring(ns.db.enabled)
					.. ", colors=" .. tostring(ns.db.showHighlights) .. ", chat boxes=" .. hooked
					.. ", issues=" .. (marker and #marker.issues or 0)
					.. ", visible marks=" .. (marker and #marker.ranges or 0)
					.. "; misspeld/froever recognized=" .. tostring(Engine:Contains("misspeld", ns.db.wowVocabulary))
					.. "/" .. tostring(Engine:Contains("froever", ns.db.wowVocabulary)))
			else ns.OpenSettings() end
		end
		driver:UnregisterEvent("ADDON_LOADED")
	elseif ns.db then
		if event == "GLOBAL_MOUSE_DOWN" and UI.panel:IsShown()
			and not UI.panel:IsMouseOver() and (not state.box or not state.box:IsMouseOver()) then
			ns.DismissPanel()
		end
		if event == "PLAYER_LOGIN" or event == "UPDATE_CHAT_WINDOWS" then wireAllBoxes() end
		if event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TARGET_CHANGED" then rememberNames() end
	end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "UPDATE_CHAT_WINDOWS", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "GLOBAL_MOUSE_DOWN"}) do
	driver:RegisterEvent(event)
end
