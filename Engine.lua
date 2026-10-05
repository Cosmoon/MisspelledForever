local _, ns = ...
local Engine = {}
ns.Engine = Engine
local U = ns.Unicode

local function normalize(word)
	return U.Lower(word)
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

-- Keep the spelling engine's public API stable while dictionary loading and
-- lookup rules live in Dictionary.lua. The active state belongs to this engine.
function Engine:Initialize(personal, languages)
	return ns.Dictionary.Initialize(self, personal, languages)
end

function Engine:SetLanguages(languages)
	return ns.Dictionary.SetLanguages(self, languages)
end

function Engine:Elision(prefix, stem, suggest)
	return ns.Dictionary.Elision(self, prefix, stem, suggest)
end

function Engine:Contains(word, includeWow)
	return ns.Dictionary.Contains(self, word, includeWow)
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
	local first, last, offset = nil, nil, 1
	local function finish()
		if first and not masked:sub(first - 1, first - 1):match("%d")
			and not masked:sub(last + 1, last + 1):match("%d") then
			tokens[#tokens + 1] = { word = text:sub(first, last), first = first, last = last }
		end
		first, last = nil, nil
	end
	for _, char in ipairs(U.Characters(masked)) do
		if U.IsLetter(char) then
			first = first or offset; last = offset + #char - 1
		elseif first and U.IsMark(char) then last = offset + #char - 1
		elseif first and (char == "'" or char == "’") then
			-- Apostrophes inside words are retained; trailing quotes are trimmed.
		else finish() end
		offset = offset + #char
	end
	finish()
	return tokens
end

function Engine:Check(text, options, ignored)
	local issues = {}
	for _, token in ipairs(self:Tokens(text)) do
		local word = normalize(token.word)
		if U.Length(word) >= options.minLength and U.Length(word) <= 28 and U.IsWord(word)
			and not (ignored and ignored[word])
			and not (options.ignoreUppercase and U.IsUpper(token.word))
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
	local sourceChars, targetChars
	if source:find("[\128-\255]") or target:find("[\128-\255]") then
		sourceChars, targetChars = U.Characters(source), U.Characters(target)
	end
	local n, m = sourceChars and #sourceChars or #source, targetChars and #targetChars or #target
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
			local a = sourceChars and sourceChars[i] or source:byte(i)
			local b = targetChars and targetChars[j] or target:byte(j)
			local cost = a == b and 0 or 1
			local value = math.min((previous[j] or limit + 1) + 1,
				(current[j - 1] or limit + 1) + 1, (previous[j - 1] or limit + 1) + cost)
			if i > 1 and j > 1 and a == (targetChars and targetChars[j - 1] or target:byte(j - 1))
				and (sourceChars and sourceChars[i - 1] or source:byte(i - 1)) == b then
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
	if U.Length(word) > 28 then return {} end
	local prefix, stem = word:match("^([^']+)'(.+)$")
	local knownPrefix = false
	if prefix then
		for _, pack in ipairs(self.elisionPacks or {}) do
			if pack.prefixes[prefix] then knownPrefix = true; break end
		end
	end
	if knownPrefix then word = stem else prefix = nil end
	local chars = U.Characters(word)
	local length = #chars
	if length > 28 or not U.IsWord(word) then return {} end
	local closeLimit = length <= 3 and 1 or 2
	local limit = length <= 3 and 1 or (length <= 10 and 3 or 4)
	local candidates, seen = {}, {}
	local hint = not prefix and self.english and ns.TypoHints[word]
	local letterCounts = {}
	for i = 1, length do
		local char = chars[i]
		letterCounts[char] = (letterCounts[char] or 0) + 1
	end
	local function enoughSharedLetters(candidate, candidateLimit)
		-- Any result within the edit limit must preserve this many letters.
		-- This cheap bound avoids running the matrix for unrelated words.
		local matched, used = 0, {}
		local required = math.max(length, #candidate) - candidateLimit
		local ascii = type(candidate) == "string"
		for i = 1, #candidate do
			local char = ascii and candidate:sub(i, i) or candidate[i]
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
		if prefix and not self:Elision(prefix, candidate, true) then return end
		if seen[candidate] or candidate == word then return end
		seen[candidate] = true
		local ascii = not candidate:find("[\128-\255]")
		local candidateChars = ascii and candidate or U.Characters(candidate)
		-- Wider matches must retain both endpoints. The tier is based on the
		-- typed word's length, not the length of a proposed correction.
		local sameEnds = chars[1] == (ascii and candidate:sub(1, 1) or candidateChars[1])
			and chars[length] == (ascii and candidate:sub(-1) or candidateChars[#candidateChars])
		local candidateLimit = sameEnds and limit or closeLimit
		if not forced and not enoughSharedLetters(candidateChars, candidateLimit) then return end
		local distance = self.Distance(word, candidate, candidateLimit)
		if not forced and distance > candidateLimit then return end
		local score = distance + (self.common[candidate] and 0.2 or 0.45)
		if options.wowVocabulary and self.wow[candidate] then score = distance + 0.08 end
		if self.personal[candidate] then score = distance + 0.1 end
		if self.english and candidate:sub(-2) == "ed" and word:sub(-1) == "d" then score = score - 0.08 end
		if length == #candidateChars then
			for i = 1, length do
				local a, b = chars[i], ascii and candidate:sub(i, i) or candidateChars[i]
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
	for size = math.max(1, length - limit), length + limit do
		for _, candidate in ipairs(self.byLength[size] or {}) do
			if self.words[candidate] or prefix then add(candidate) end
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
	for i = 1, math.min(options.maxSuggestions, #candidates) do
		result[i] = (prefix and prefix .. "'" or "") .. candidates[i].word
	end
	return result
end

function Engine.Replace(text, token, replacement, cursor)
	if text:sub(token.first, token.last) ~= token.word then return nil end
	if U.IsUpper(token.word) then
		replacement = U.Upper(replacement)
	elseif U.InitialUpper(token.word) then
		replacement = U.Title(replacement)
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
