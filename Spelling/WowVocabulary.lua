local _, ns = ...
local U = ns.Unicode
local Vocabulary = {}; ns.WowVocabulary = Vocabulary

local function canonical(text)
	return U.Lower(text):gsub("%s+", " ")
end

function Vocabulary.Build(languages)
	local root, words, loaded = {}, {}, {}
	local function addPack(locale)
		locale = locale == "enGB" and "enUS" or (locale == "nlBE" and "nlNL" or locale)
		if loaded[locale] then return end
		loaded[locale] = true
		for _, category in pairs((ns.WowLanguagePacks or {})[locale] or {}) do
			for term in pairs(category) do
				term = canonical(term)
				words[term] = true
				local node = root
				for _, char in ipairs(U.Characters(term)) do
					node[char] = node[char] or {}; node = node[char]
				end
				node.complete = true
			end
		end
	end
	-- English names and aliases are shared by international WoW chat.
	addPack("enUS")
	for locale in pairs(languages) do addPack(locale) end
	return root, words
end

local function wordChar(char)
	return char and (U.IsLetter(char) or U.IsMark(char) or char:match("%d") or char == "'")
end

-- Match the longest complete name at a word boundary. Work on normalized,
-- masked text; flags use token order so original UTF-8 cursor offsets survive.
function Vocabulary.Accepted(engine, text)
	-- Mask case-sensitive WoW escape codes before converting letters to lowercase.
	local _, masked = engine:Tokens(text, "\001")
	local tokens
	tokens, masked = engine:Tokens(U.Lower(masked), "\001")
	local chars, starts, ends, offset = U.Characters(masked), {}, {}, 1
	for i, char in ipairs(chars) do
		starts[i], ends[i] = offset, offset + #char - 1
		offset = offset + #char
	end
	local accepted, i, tokenIndex = {}, 1, 1
	while i <= #chars do
		local last
		if not wordChar(chars[i - 1]) then
			local node, j = engine.wowTrie, i
			while node and j <= #chars do
				local char = chars[j]
				if char:match("%s") then
					char = " "
					while chars[j + 1] and chars[j + 1]:match("%s") do j = j + 1 end
				end
				node = node[char]
				if node and node.complete and not wordChar(chars[j + 1]) then last = j end
				j = j + 1
			end
		end
		if last then
			while tokens[tokenIndex] and tokens[tokenIndex].first < starts[i] do tokenIndex = tokenIndex + 1 end
			while tokens[tokenIndex] and tokens[tokenIndex].last <= ends[last] do
				accepted[tokenIndex] = true; tokenIndex = tokenIndex + 1
			end
			i = last + 1
		else i = i + 1 end
	end
	return accepted
end
