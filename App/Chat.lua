local _, ns = ...
local Engine, UI = ns.Engine, ns.UI
local Chat = {}
ns.Chat = Chat

-- Chat state stays private: pending checks, suggestion jobs and their snapshots
-- must be invalidated together when input or options change.
local state = { hooked = {}, ignored = {}, cache = {}, cacheOrder = {} }

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
	Engine:SetLanguages(ns.db.languages)
	UI:RefreshOptions(); UI:UpdateMinimap()
	UI.panel:Hide()
	UI:ClearMarks()
	state.pendingAt = GetTime() + 0.05
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
	if count >= 800 then ns.PrintMessage("Your personal dictionary is full. Edit it in /mf."); return end
	if ns.ValidPersonalWord(word) then
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
		ns.PrintMessage("That correction would exceed the chat length limit.")
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

function Chat:Update()
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
end

function Chat:Initialize()
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
end

function Chat:HandleEvent(event)
	if event == "GLOBAL_MOUSE_DOWN" and UI.panel:IsShown()
		and not UI.panel:IsMouseOver() and (not state.box or not state.box:IsMouseOver()) then
		ns.DismissPanel()
	end
	if event == "PLAYER_LOGIN" or event == "UPDATE_CHAT_WINDOWS" then wireAllBoxes() end
	if event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TARGET_CHANGED" then rememberNames() end
end

function Chat:PrintDebug()
	local hooked = 0
	for _ in pairs(state.hooked) do hooked = hooked + 1 end
	local marker = state.box and UI.markers[state.box]
	ns.PrintMessage("Color build 1; checking=" .. tostring(ns.db.enabled)
		.. ", colors=" .. tostring(ns.db.showHighlights) .. ", chat boxes=" .. hooked
		.. ", issues=" .. (marker and #marker.issues or 0)
		.. ", visible marks=" .. (marker and #marker.ranges or 0)
		.. "; misspeld/froever recognized=" .. tostring(Engine:Contains("misspeld", ns.db.wowVocabulary))
		.. "/" .. tostring(Engine:Contains("froever", ns.db.wowVocabulary)))
end
