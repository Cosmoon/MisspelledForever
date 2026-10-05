local _, ns = ...
local Engine, UI = ns.Engine, ns.UI

local defaults = {
	enabled = true, showHighlights = true, wowVocabulary = true, ignoreUppercase = true,
	showMinimap = true, minimapAngle = 220, maxSuggestions = 6, panelScale = 1,
	languages = { enUS = true, enGB = false, deDE = false, frFR = false, esES = false, itIT = false, nlNL = false, nlBE = false },
	minLength = 2, highlightColor = { 1, 0.42, 0.34 }, personalWords = {},
	channels = { SAY = true, YELL = true, WHISPER = true, GUILD = true,
		OFFICER = true, PARTY = true, RAID = true, INSTANCE_CHAT = true,
		CHANNEL = true, EMOTE = false },
}

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

function ns.SetOption(key, value)
	ns.db[key] = value
	ns.OptionsChanged()
end

function ns.SetLanguage(code, enabled)
	if not ns.LanguagePacks[code] then return end
	local count = 0
	for _, entry in ipairs(ns.Languages) do
		if ns.db.languages[entry[1]] then count = count + 1 end
	end
	if (not enabled and count <= 1 and ns.db.languages[code])
		or (enabled and count >= ns.MaxLanguages and not ns.db.languages[code]) then
		UI:RefreshOptions(); return
	end
	ns.db.languages[code] = enabled == true
	ns.OptionsChanged()
end

function ns.ResetOptions()
	local personal = ns.db.personalWords
	for key, value in pairs(defaults) do ns.db[key] = copy(value) end
	ns.db.personalWords = personal
	ns.OptionsChanged()
end

function ns.ValidPersonalWord(word)
	return ns.Unicode.Length(word) >= 2 and ns.Unicode.Length(word) <= 28
		and ns.Unicode.IsWord(word) and not word:find("''", 1, true)
		and word:sub(1, 1) ~= "'" and word:sub(-1) ~= "'"
end

function ns.SavePersonalWords(text)
	local words, count = {}, 0
	for line in text:gmatch("[^\r\n]+") do
		local word = Engine.Normalize(line:match("^%s*(.-)%s*$"))
		if word ~= "" then
			if not ns.ValidPersonalWord(word) then
				return nil, "Use one word per line (2-28 Latin letters; accents and apostrophes allowed)."
			end
			if not words[word] then words[word] = true; count = count + 1 end
			if count > 800 then return nil, "The personal dictionary supports up to 800 words." end
		end
	end
	ns.db.personalWords, Engine.personal = words, words
	ns.OptionsChanged()
	return count
end

function ns.InitializeSettings()
	MisspelledForeverDB = type(MisspelledForeverDB) == "table" and MisspelledForeverDB or {}
	ns.db = MisspelledForeverDB
	restoreDefaults(ns.db, defaults)
	ns.db.autoPanel, ns.db.showUnderlines = nil, nil -- Retire popup/underline settings.
	ns.db.maxSuggestions = math.floor(math.max(2, math.min(8, ns.db.maxSuggestions)))
	ns.db.panelScale = math.max(0.8, math.min(1.4, ns.db.panelScale))
	ns.db.minLength = math.max(2, math.min(5, ns.db.minLength))
	for i = 1, 3 do ns.db.highlightColor[i] = math.max(0, math.min(1, ns.db.highlightColor[i])) end
	for word, value in pairs(ns.db.personalWords) do
		if type(word) ~= "string" or not ns.ValidPersonalWord(word) or value ~= true then ns.db.personalWords[word] = nil end
	end
	local languageCount = 0
	for _, entry in ipairs(ns.Languages) do
		if ns.db.languages[entry[1]] then
			languageCount = languageCount + 1
			if languageCount > ns.MaxLanguages then ns.db.languages[entry[1]] = false end
		end
	end
	if languageCount == 0 then ns.db.languages.enUS = true end
end
