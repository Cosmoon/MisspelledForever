local _, ns = ...
local Dictionary = {}
ns.Dictionary = Dictionary
local U = ns.Unicode
local normalize = U.Lower

-- These methods operate on the engine's active dictionary state.
-- Packed source data stays available so languages can change without a reload.
-- Sorted word chunks store a byte-prefix length followed by the new suffix.
-- Prefix boundaries are always complete UTF-8 characters.
local function packWords(pack, visit)
	for _, chunk in ipairs(pack.chunks) do
		if pack.packed then
			local previous = ""
			for line in chunk:gmatch("[^\r\n]+") do
				local word = previous:sub(1, tonumber(line:sub(1, 2), 16)) .. line:sub(3)
				visit(word); previous = word
			end
		else
			for word in chunk:gmatch("%S+") do visit(word) end
		end
	end
end

function Dictionary:Initialize(personal, languages)
	self.words, self.byLength, self.common, self.wow, self.names = {}, {}, {}, {}, {}
	self.personal = personal or {}
	self.languageSignature = nil
	self:SetLanguages(languages)
	local rank = 0
	for word in ns.CommonWords:gmatch("%S+") do
		rank = rank + 1
		self.common[normalize(word)] = rank
	end
	for word in ns.WowWords:gmatch("%S+") do self.wow[normalize(word)] = true end
end

function Dictionary:SetLanguages(languages)
	languages = languages or { enUS = true }
	local signature, selected = {}, {}
	for _, entry in ipairs(ns.Languages) do
		if languages[entry[1]] and #signature < ns.MaxLanguages then
			signature[#signature + 1] = entry[1]; selected[entry[1]] = true
		end
	end
	if #signature == 0 then signature[1], selected.enUS = "enUS", true end
	languages = selected
	signature = table.concat(signature, ",")
	if self.languageSignature == signature then return end
	self.languageSignature = signature
	self.english = languages.enUS or languages.enGB
	self.words, self.byLength, self.elisionPacks = {}, {}, {}
	local loaded = {}
	for _, entry in ipairs(ns.Languages) do
		local pack = ns.LanguagePacks[entry[1]]
		if languages[entry[1]] and pack and not loaded[pack] then
			loaded[pack] = true
			local blocked = {}
			for _, chunk in ipairs(pack.blocked) do
				for word in chunk:gmatch("%S+") do blocked[word] = true end
			end
			packWords(pack, function(word)
				if self.words[word] == nil then
					local length = U.Length(word)
					local bucket = self.byLength[length]
					if not bucket then bucket = {}; self.byLength[length] = bucket end
					bucket[#bucket + 1] = word
				end
				self.words[word] = self.words[word] or not blocked[word]
			end)
		end
	end
	-- Elisions share a stem plus a compact set of permitted prefixes. This
	-- avoids expanding millions of l'/d'/all' variants into the active index.
	local indexed = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for pack in pairs(loaded) do
		if pack.elisions and #pack.elisions > 0 then
			local data = { prefixes = {}, forms = {} }
			for i, prefix in ipairs(pack.prefixes) do
				data.prefixes[prefix] = pack.elisionEncoding == "indices" and ("," .. i .. ",") or alphabet:sub(i, i)
			end
			for _, chunk in ipairs(pack.elisions) do
				local previous = ""
				for word, codes in chunk:gmatch("(%S+) (%S+)") do
					if pack.packed then
						word = previous:sub(1, tonumber(word:sub(1, 2), 16)) .. word:sub(3)
						previous = word
						codes = pack.elisionFlags[tonumber(codes)]
					end
					data.forms[word] = codes
					if self.words[word] == nil and not indexed[word] then
						indexed[word] = true
						local length = U.Length(word)
						self.byLength[length] = self.byLength[length] or {}
						local bucket = self.byLength[length]; bucket[#bucket + 1] = word
					end
				end
			end
			self.elisionPacks[#self.elisionPacks + 1] = data
		end
	end
end

function Dictionary:Elision(prefix, stem, suggest)
	for _, pack in ipairs(self.elisionPacks or {}) do
		local code, flags = pack.prefixes[prefix], pack.forms[stem]
		if code and flags then
			local accepted, suggested = flags:match("^(.-):(.*)$")
			if (suggest and suggested or accepted):find(code, 1, true) then return true end
		end
	end
	return false
end

function Dictionary:Contains(word, includeWow)
	word = normalize(word)
	local prefix, stem = word:match("^([^']+)'(.+)$")
	return self.words[word] ~= nil or self.personal[word] or self.names[word]
		or (includeWow and self.wow[word]) or (prefix and self:Elision(prefix, stem, false)) or false
end
