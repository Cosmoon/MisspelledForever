local _, ns = ...
local Engine = {}
ns.Engine = Engine

local function normalize(word)
	return word:gsub("’", "'"):lower()
end
Engine.Normalize = normalize

-- Remove only the private color prefixes used by this addon's edit-box
-- highlights, translating a byte cursor back into the original text.
function Engine.StripHighlights(text, prefixes, cursor)
	local parts, i, length, depth = {}, 1, 0, 0
	local plainCursor = 0
	cursor = cursor or #text
	while i <= #text do
		local prefix = text:sub(i, i + 9)
		if prefixes and prefixes[prefix] then
			depth = depth + 1; i = i + 10
		elseif depth > 0 and text:sub(i, i + 1) == "|r" then
			depth = depth - 1; i = i + 2
		else
			parts[#parts + 1] = text:sub(i, i)
			length = length + 1; i = i + 1
		end
		if i - 1 <= cursor then plainCursor = length end
	end
	return table.concat(parts), plainCursor
end

function Engine:Initialize(personal)
	self.words, self.byLength, self.common, self.wow, self.names = {}, {}, {}, {}, {}
	self.personal = personal or {}
	local blocked = {}
	for _, chunk in ipairs(ns.NoSuggestChunks) do
		for word in chunk:gmatch("%S+") do blocked[word] = true end
	end
	for _, chunk in ipairs(ns.DictionaryChunks) do
		for word in chunk:gmatch("%S+") do
			self.words[word] = not blocked[word]
			local bucket = self.byLength[#word]
			if not bucket then bucket = {}; self.byLength[#word] = bucket end
			bucket[#bucket + 1] = word
		end
	end
	local rank = 0
	for word in ns.CommonWords:gmatch("%S+") do
		rank = rank + 1
		self.common[normalize(word)] = rank
	end
	for word in ns.WowWords:gmatch("%S+") do self.wow[normalize(word)] = true end
	ns.DictionaryChunks, ns.NoSuggestChunks = nil, nil
end

function Engine:Contains(word, includeWow)
	word = normalize(word)
	return self.words[word] ~= nil or self.personal[word] or self.names[word]
		or (includeWow and self.wow[word]) or false
end

-- Keep byte offsets aligned with the original edit box text. Hyperlinks and
-- formatting stay intact when a user explicitly replaces a word.
function Engine:Tokens(text)
	local function spaces(value) return string.rep(" ", #value) end
	local masked = text:gsub("|H.-|h.-|h", spaces)
		:gsub("|T.-|t", spaces):gsub("|A.-|a", spaces)
		:gsub("|c%x%x%x%x%x%x%x%x", spaces):gsub("|r", spaces)
		:gsub("https?://%S+", spaces):gsub("www%.%S+", spaces)
		:gsub("[%w._%%+%-]+@[%w.%-]+%.[%a]+", spaces)
		:gsub("{[^}]+}", spaces)
	local tokens = {}
	if text:match("^%s*/") then return tokens end
	for first, word, after in masked:gmatch("()([%a\128-\255][%a\128-\255']*)()") do
		while word:sub(1, 3) == "’" do word = word:sub(4); first = first + 3 end
		while word:sub(-3) == "’" do word = word:sub(1, -4) end
		word = word:gsub("'+$", "")
		local last = first + #word - 1
		if not masked:sub(first - 1, first - 1):match("%d")
			and not masked:sub(after, after):match("%d") then
			tokens[#tokens + 1] = { word = text:sub(first, last), first = first, last = last }
		end
	end
	return tokens
end

function Engine:Check(text, options, ignored)
	local issues = {}
	for _, token in ipairs(self:Tokens(text)) do
		local word = normalize(token.word)
		-- This first version is English. Skip foreign-script words instead of
		-- pretending that byte-based English matching can validate them.
		if #word >= options.minLength and #word <= 28 and not word:find("[\128-\255]")
			and not (ignored and ignored[word])
			and not (options.ignoreUppercase and token.word:match("^[A-Z]+$"))
			and not self:Contains(word, options.wowVocabulary) then
			token.normalized = word
			issues[#issues + 1] = token
		end
	end
	return issues
end

-- Banded optimal-string-alignment distance: insertion, deletion, substitution,
-- and adjacent transposition. A bounded search discards distant words early.
function Engine.Distance(source, target, limit)
	local n, m = #source, #target
	limit = limit or math.max(n, m)
	if math.abs(n - m) > limit then return limit + 1 end
	if n == 0 then return m end
	if m == 0 then return n end
	local previous, beforePrevious = {}, {}
	for j = 0, m do previous[j] = j end
	for i = 1, n do
		local current = { [0] = i }
		local from, to = math.max(1, i - limit), math.min(m, i + limit)
		local rowMin = limit + 1
		for j = from, to do
			local cost = source:byte(i) == target:byte(j) and 0 or 1
			local value = math.min((previous[j] or limit + 1) + 1,
				(current[j - 1] or limit + 1) + 1, (previous[j - 1] or limit + 1) + cost)
			if i > 1 and j > 1 and source:byte(i) == target:byte(j - 1)
				and source:byte(i - 1) == target:byte(j) then
				value = math.min(value, (beforePrevious[j - 2] or limit + 1) + 1)
			end
			current[j], rowMin = value, math.min(rowMin, value)
		end
		if rowMin > limit then return limit + 1 end
		beforePrevious, previous = previous, current
	end
	return previous[m] or limit + 1
end

local keyboard = {
	q = "wa", w = "qeas", e = "wrsd", r = "etdf", t = "ryfg", y = "tugh",
	u = "yihj", i = "uojk", o = "ipkl", p = "ol", a = "qwsz", s = "awedxz",
	d = "serfcx", f = "drtgvc", g = "ftyhbv", h = "gyujnb", j = "huikmn",
	k = "jiolm", l = "kop", z = "asx", x = "zsdc", c = "xdfv",
	v = "cfgb", b = "vghn", n = "bhjm", m = "njk",
}

function Engine:Suggest(word, options, yieldWork)
	word = normalize(word)
	if #word > 28 or word:find("[\128-\255]") then return {} end
	local closeLimit = #word <= 3 and 1 or 2
	local limit = #word <= 3 and 1 or (#word <= 10 and 3 or 4)
	local candidates, seen = {}, {}
	local hint = ns.TypoHints[word]
	local letterCounts = {}
	for i = 1, #word do
		local char = word:byte(i)
		letterCounts[char] = (letterCounts[char] or 0) + 1
	end
	local function enoughSharedLetters(candidate, candidateLimit)
		-- Any result within the edit limit must preserve this many letters.
		-- This cheap bound avoids running the matrix for unrelated words.
		local matched, used = 0, {}
		local required = math.max(#word, #candidate) - candidateLimit
		for i = 1, #candidate do
			local char = candidate:byte(i)
			if letterCounts[char] then
				local count = (used[char] or 0) + 1
				used[char] = count
				if count <= letterCounts[char] then matched = matched + 1 end
			end
			if matched >= required then return true end
			if matched + #candidate - i < required then return false end
		end
		return matched >= required
	end
	local function add(candidate, forced)
		if seen[candidate] or candidate == word then return end
		seen[candidate] = true
		-- Wider matches must retain both endpoints. The tier is based on the
		-- typed word's length, not the length of a proposed correction.
		local sameEnds = word:byte(1) == candidate:byte(1)
			and word:byte(-1) == candidate:byte(-1)
		local candidateLimit = sameEnds and limit or closeLimit
		if not forced and not enoughSharedLetters(candidate, candidateLimit) then return end
		local distance = self.Distance(word, candidate, candidateLimit)
		if not forced and distance > candidateLimit then return end
		local score = distance + (self.common[candidate] and 0.2 or 0.45)
		if options.wowVocabulary and self.wow[candidate] then score = distance + 0.08 end
		if self.personal[candidate] then score = distance + 0.1 end
		if candidate:sub(-2) == "ed" and word:sub(-1) == "d" then score = score - 0.08 end
		if #word == #candidate then
			for i = 1, #word do
				local a, b = word:sub(i, i), candidate:sub(i, i)
				if a ~= b and keyboard[a] and keyboard[a]:find(b, 1, true) then
					score = score - 0.025
				end
			end
		end
		if forced then score = -1 end
		candidates[#candidates + 1] = { word = candidate, distance = distance, score = score,
			wide = not forced and distance > closeLimit }
	end
	if hint then
		local valid = true
		for piece in hint:gmatch("%S+") do
			if not self:Contains(piece, options.wowVocabulary) then valid = false end
		end
		if valid then add(hint, true) end
	end
	local visited = 0
	for length = math.max(1, #word - limit), #word + limit do
		for _, candidate in ipairs(self.byLength[length] or {}) do
			if self.words[candidate] then add(candidate) end
			visited = visited + 1
			if yieldWork and visited % 120 == 0 then yieldWork() end
		end
	end
	if options.wowVocabulary then
		for candidate in pairs(self.wow) do add(candidate) end
	end
	for candidate in pairs(self.personal) do add(candidate) end
	table.sort(candidates, function(a, b)
		if a.wide ~= b.wide then return not a.wide end
		if a.score ~= b.score then return a.score < b.score end
		local ar, br = self.common[a.word] or 99999, self.common[b.word] or 99999
		if ar ~= br then return ar < br end
		return a.word < b.word
	end)
	local result = {}
	for i = 1, math.min(options.maxSuggestions, #candidates) do result[i] = candidates[i].word end
	return result
end

function Engine.Replace(text, token, replacement, cursor)
	if text:sub(token.first, token.last) ~= token.word then return nil end
	if token.word:match("^[A-Z][A-Z']+$") then
		replacement = replacement:upper()
	elseif token.word:match("^[A-Z]") then
		replacement = replacement:sub(1, 1):upper() .. replacement:sub(2)
	end
	local value = text:sub(1, token.first - 1) .. replacement .. text:sub(token.last + 1)
	local nextCursor = cursor or token.last
	if nextCursor >= token.last then
		nextCursor = nextCursor + #replacement - #token.word
	elseif nextCursor >= token.first - 1 then
		nextCursor = token.first - 1 + #replacement
	end
	return value, math.max(0, math.min(#value, nextCursor))
end
